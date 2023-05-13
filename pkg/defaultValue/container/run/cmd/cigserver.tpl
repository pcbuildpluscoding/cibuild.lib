// The MIT License
//
// Copyright (c) 2023 Peter A McGill
package main

import (
  "context"
  "fmt"
  "net"
  "os"
  "os/signal"
  "syscall"
  "time"

  ab "github.com/pcbuildpluscoding/apibase/std"
  _ "github.com/pcbuildpluscoding/appware/std"

  crn "github.com/pcbuildpluscoding/cibuild/lib/defaultValue/container/run"
  cib "github.com/pcbuildpluscoding/cibuild/std"
  _ "github.com/pcbuildpluscoding/flowware/std"
  elm "github.com/pcbuildpluscoding/genware/lib/element"
  han "github.com/pcbuildpluscoding/genware/lib/handler"

  rdt "github.com/pcbuildpluscoding/types/apirecord"
  awt "github.com/pcbuildpluscoding/types/appware"
  fwt "github.com/pcbuildpluscoding/types/flowware"
)

var (
  awStdRegKey string
  fwStdRegKey string
)

type ApiClient = fwt.ApiClient
type ApiRecord = rdt.ApiRecord
type ApiResult = ab.ApiResult
type EndptProvider = cib.EndptProvider
type ScanServer = cib.ScanServer

// -------------------------------------------------------------- //
// init
// ---------------------------------------------------------------//
func init() {
  awStdRegKey = os.Getenv("APPWARE_STD_V0_REGKEY")
  if awStdRegKey == "" {
    awStdRegKey = "appware/std/v0"
  }
  fwStdRegKey = os.Getenv("FLOWWARE_STD_V0_REGKEY")
  if fwStdRegKey == "" {
    fwStdRegKey = "flowware/std/v0"
  }
}

// -------------------------------------------------------------- //
// main
// ---------------------------------------------------------------//
func serve() error {
  cib.SetLogger(logger, logfd)
  crn.SetLogger(logger)
  han.SetLogger(logger)
  elm.SetLogger(logger, logfd)

  server, err := newCigServer()

  if err != nil {
    return fmt.Errorf("ScanServer creation errored : %v", err)
  }

  err = run(server)
  
  logger.Infof("ScanServer is now closed")
  return err
}

// -------------------------------------------------------------- //
// run
// ---------------------------------------------------------------//
func run(server CigServer) error {
  logger.Infof("%s is starting ...", server.Desc)

  ctx, cancel := context.WithCancel(context.Background())
  defer cancel()

  statusCh := make(chan ApiRecord, 1)
  
  err := server.Start(ctx, statusCh)

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

//================================================================//
// CigServer
//================================================================//
type CigServer struct {
  Desc string
  server *ScanServer
  jobId string
}

// ---------------------------------------------------------------//
// AppFailed
// ---------------------------------------------------------------//
func (b *CigServer) AppFailed(rcd ApiRecord) bool {
  return rcd.Code() >= 500
}

// -------------------------------------------------------------- //
// newClient
// ---------------------------------------------------------------//
func (b *CigServer) newClient() (ApiClient, error) {
  logger.Debugf("connecting to the resume server at : %s", resumeAddr)
  conn, err := net.Dial("tcp", resumeAddr)
  if err != nil {
    return nil, err
  } 

  fw, err := fwt.GetApiFW(fwStdRegKey)
  client := fw.NewClient(conn, b.jobId)
  return client, err
}

// ---------------------------------------------------------------//
// Run
// ---------------------------------------------------------------//
func (b *CigServer) Run() {
  go b.server.Run()

  if b.jobId == "" {
    logger.Debugf("%s jobId is undefined - resume request aborted ...", b.Desc)
    return
  }

  resumeReq := map[string]interface{}{
    "JobId": b.jobId,
    "State": "Resume",
  }

  client, err := b.newClient()
  if err != nil {
    b.server.FwdWithf(500, "%s - resume client creation failed : %v", b.Desc, err)
    return
  }

  aw, err := awt.Get(awStdRegKey, resumeReq)
  if err != nil {
    b.server.FwdWithf(500, "%s - resume request vendoring failed : %v", b.Desc, err)
    return
  }

  logger.Infof("%s client is sending a new resume request", b.Desc)

  resp := client.Request(aw)
  if resp.AppFailed() {
    b.server.FwdWithf(500, "%s - resume server request failed : %v", b.Desc, resp.Unwrap())
    return
  }
}

// ---------------------------------------------------------------//
// Start
// ---------------------------------------------------------------//
func (b *CigServer) Start(ctx context.Context, superCh chan ApiRecord) error {
  return b.server.Start(ctx, bindAddr, superCh)
}

// ---------------------------------------------------------------//
// newCigServer
// ---------------------------------------------------------------//
func newCigServer() (CigServer, error) {
  jobId := os.Getenv("CIBUILD_JOB_ID")
  if jobId == "" {
    return CigServer{}, fmt.Errorf("CIBUILD_JOB_ID environment var is undefined - resume request dispatch failed")
  }

  server, err := newServer()

  return CigServer{
    Desc: "CigServer-" + time.Now().Format("150405.000000"),
    server: server,
    jobId: jobId,
  }, err
}

// ---------------------------------------------------------------//
// newServer
// ---------------------------------------------------------------//
func newServer() (*ScanServer, error) {

  provider, err := newProvider()

  if err != nil {
    return nil, err
  }

  return provider.NewScanServer()
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
