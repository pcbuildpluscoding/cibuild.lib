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
  "sigs.k8s.io/yaml"

  crg "github.com/pcbuildpluscoding/cibuild/lib/runtime/container/run"
  prg "github.com/pcbuildpluscoding/cibuild/lib/progen"
  cib "github.com/pcbuildpluscoding/cibuild/std"
  _ "github.com/pcbuildpluscoding/flowware/std"
  elm "github.com/pcbuildpluscoding/genware/lib/element"
  fs "github.com/pcbuildpluscoding/genware/lib/filesystem"

  stx "github.com/pcbuildpluscoding/strucex/std"
  rdt "github.com/pcbuildpluscoding/types/apirecord"
  awt "github.com/pcbuildpluscoding/types/appware"
  fwt "github.com/pcbuildpluscoding/types/flowware"
  rwt "github.com/pcbuildpluscoding/types/runware"
  spb "google.golang.org/protobuf/types/known/structpb"
)

var (
  awStdRegKey string
  fwStdRegKey string
)

type ApiClient = fwt.ApiClient
type ApiRecord = rdt.ApiRecord
type ApiResult = ab.ApiResult
type EndptProvider = cib.EndptProvider
type Runware = rwt.Runware
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
  crg.SetLogger(logger, logfd)
  prg.SetLogger(logger, logfd)
  elm.SetLogger(logger, logfd)
  fs.SetLogger(logger)

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
  jobKey string
  ciAction string
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
func (b *CigServer) newClient(remoteAddr string) (ApiClient, error) {
  logger.Debugf("connecting to remote address : %s", remoteAddr)
  conn, err := net.Dial("tcp", remoteAddr)
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
  if b.ciAction == "Start" {
    err := b.sendImportReq()
    if err != nil {
      logger.Error(err)
      b.server.FwdError(err)
      return
    }
  }

  go b.server.Run()

  b.sendCiReq()
}

// ---------------------------------------------------------------//
// sendImportReq
// ---------------------------------------------------------------//
func (b *CigServer) sendImportReq() error {
  configPath := os.Getenv("CI_SCHEDULE")
  if configPath == "" {
    return fmt.Errorf("CI_SCHEDULE environment var is undefined, aborting ...")
  }

  importReq, err := getImportReq(configPath)
  if err != nil {
    return err
  }

  b.jobKey = importReq.String("JobKey")

  client, err := b.newClient(scanifyAddr)

  aw, err := awt.Get(awStdRegKey, importReq.AsMap())
  if err != nil {
    return fmt.Errorf("%s - import request vendoring failed : %v", b.Desc, err)
  }

  logger.Infof("%s client is sending a job schedule import request ...", b.Desc)

  resp := client.Request(aw)
  if resp.AppFailed() {
    return fmt.Errorf("%s - trovient import request failed : %v", b.Desc, resp.Unwrap())
  }
  return nil
}

// ---------------------------------------------------------------//
// sendCiReq
// ---------------------------------------------------------------//
func (b *CigServer) sendCiReq() {

  if b.jobId == "" {
    logger.Debugf("%s jobId is undefined - %s request aborted ...", b.Desc, b.ciAction)
    return
  }

  request := map[string]interface{}{
    "JobId": b.jobId,
    "Action": b.ciAction,
    "ResumeRef": map[string]interface{}{
      "TaskId": os.Getenv("CI_RESUMABLE_TASK_ID"),
    },
  }

  if b.ciAction == "Start" {
    request["JobKey"] = b.jobKey
  }

  client, err := b.newClient(resumeAddr)
  if err != nil {
    b.server.FwdWithf(500, "%s - client creation failed : %v", b.Desc, err)
    return
  }

  aw, err := awt.Get(awStdRegKey, request)
  if err != nil {
    b.server.FwdWithf(500, "%s - %s request vendoring failed : %v", b.Desc, b.ciAction, err)
    return
  }

  logger.Infof("%s client is sending a new %s request", b.Desc, b.ciAction)

  resp := client.Request(aw)
  if resp.AppFailed() {
    b.server.FwdWithf(500, "%s - ciserver request failed : %v", b.Desc, resp.Unwrap())
    return
  }
}

// ---------------------------------------------------------------//
// Start
// ---------------------------------------------------------------//
func (b *CigServer) Start(ctx context.Context, superCh chan ApiRecord) error {
  logger.Debugf("%s is starting ...", b.Desc)
  return b.server.Start(ctx, bindAddr, superCh)
}

// ---------------------------------------------------------------//
// newCigServer
// ---------------------------------------------------------------//
func newCigServer() (CigServer, error) {
  logger.Debugf("creating cigserver ...")

  jobId := os.Getenv("CI_JOB_ID")
  if jobId == "" {
    return CigServer{}, fmt.Errorf("CI_JOB_ID environment var is undefined, aborting ...")
  }

  action := os.Getenv("CI_ACTION")
  if action == "" {
    return CigServer{}, fmt.Errorf("CI_ACTION environment var is undefined, aborting ...")
  }

  server, err := newServer()

  return CigServer{
    Desc: "CigServer-" + time.Now().Format("150405.000000"),
    server: server,
    jobId: jobId,
    ciAction: action,
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

//------------------------------------------------------------------//
//  getImportReq
//------------------------------------------------------------------//
func getImportReq(inputPath string) (Runware, error) {

  var frame []byte

  frame, err := os.ReadFile(inputPath)
  if err != nil {
    return nil, err
  }
  frame, err = yaml.YAMLToJSON(frame)
  if err != nil {
    return nil, fmt.Errorf("YAMLToJson conversion failed : %v", err)
  }

  logger.Debugf("about to run structpb.Value unmarshaling on the jobspec.yaml input ...")

  value,_ := spb.NewValue(nil)
  err = value.UnmarshalJSON(frame)

  if err != nil {
    return nil, fmt.Errorf("structpb.Value unmarshaling of yaml or json file failed : %v", err)
  }

  return stx.NewRunware(value)
}
