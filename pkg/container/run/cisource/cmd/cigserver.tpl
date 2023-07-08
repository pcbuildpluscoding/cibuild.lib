// The MIT License
//
// Copyright (c) 2023 Peter A McGill
package main

import (
  "context"
  "fmt"
  "os"
  "os/signal"
  "syscall"
  "time"

  gwr "github.com/pcbuildpluscoding/cibuild/genware/std"
  cib "github.com/pcbuildpluscoding/cibuild/std"
  stm "github.com/pcbuildpluscoding/scanify/std"

  fs "github.com/pcbuildpluscoding/genware/lib/filesystem"
  rdt "github.com/pcbuildpluscoding/types/apirecord"
)

type ApiRecord = rdt.ApiRecord
type EndptProvider = cib.EndptProvider
type CigServer = cib.CigServer

// -------------------------------------------------------------- //
// main
// ---------------------------------------------------------------//
func serve() error {
  cib.SetLogger(logger, logfd)
  fs.SetLogger(logger)
  gwr.SetLogger(logger)
  stm.SetLogger(logger, logfd)

  server, err := newCigServer()

  if err != nil {
    return fmt.Errorf("cigserver creation errored : %v", err)
  }

  err = run(server)
  
  logger.Infof("cigserver is now closed")
  return err
}

// -------------------------------------------------------------- //
// run
// ---------------------------------------------------------------//
func run(server *CigServer) error {
  logger.Infof("%s is starting ...", server.Desc)

  ctx, cancel := context.WithCancel(context.Background())
  defer cancel()

  statusCh := make(chan ApiRecord, 1)
  
  err := server.Start(ctx, bindAddr, statusCh)

  if err != nil {
    return err
  }

  go server.Run()

  sigCh := make(chan os.Signal, 1)
  defer close(sigCh)
  
  signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM, syscall.SIGPIPE)

  // waiting for shutdown
  for {
    select {
    case status := <-statusCh:
      logger.Infof("Got a status result : %v", status)
      if server.AppFailed(status) {
        return fmt.Errorf("%s caught an error : %v", server.Desc, status.AsMap())
      }
    case signal := <-sigCh:
      errmsg := "@@@@@@@@@@@@@@@@@ signal %v detected, %s is shutting down ... @@@@@@@@@@@@@@@@@@"
      logger.Infof(errmsg, signal, server.Desc)
      return nil
    }
  }
}

// ---------------------------------------------------------------//
// newCigServer
// ---------------------------------------------------------------//
func newCigServer() (*CigServer, error) {

  provider, err := newProvider()

  if err != nil {
    return nil, err
  }

  return provider.NewCigServer()
}

// ---------------------------------------------------------------//
// newProvider
// ---------------------------------------------------------------//
func newProvider() (*EndptProvider, error) {

  duration, err := time.ParseDuration(taskTimeout)

  if err != nil {
    return nil, err
  }

  return cib.NewEndptProvider(troveAddr, duration)
}
