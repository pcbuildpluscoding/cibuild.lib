package codegen

import (
  "fmt"
  "io"
  "net"
  "os"
  "text/scanner"

  ab "github.com/pcbuildpluscoding/apibase/std"
  stm "github.com/pcbuildpluscoding/cibuild/stream"
  "github.com/pcbuildpluscoding/logroll"
  tdb "github.com/pcbuildpluscoding/trovedb/std"
  rdt "github.com/pcbuildpluscoding/types/apirecord"
  rwt "github.com/pcbuildpluscoding/types/runware"
  xs "github.com/pcbuildpluscoding/xstring"
  "github.com/sirupsen/logrus"
)

type ApiResult = ab.ApiResult
type ApiRecord = rdt.ApiRecord
type FlowRule = tdb.FlowRule
type Runware = rwt.Runware
type StreamClient = stm.StreamClient
type Trovian = tdb.Trovian
type XString = xs.XString

var (
  logger = logroll.Get()
  troveAddr = "127.0.0.1:5599"
  linecount int
)

const widthPattern string = "%c %d%c"

// -------------------------------------------------------------- //
// SetLogger
// ---------------------------------------------------------------//
func SetLogger(super *logrus.Logger) {
  logger = super
}

//================================================================//
// ScanData
//================================================================//
type ScanData struct {
  trune rune
  Token string
  LineNum int
  fmtWidth int
  TknIndex int
}

//================================================================//
// NewTrovian
//================================================================//
func newTrovian(netAddr, bucket string) (*Trovian, error) {

//  logger.Debugf("dialing trovedb address %s ...", netAddr)
  
  conn, err := net.Dial("tcp", netAddr)
  
  if err != nil {
    return nil, fmt.Errorf("dialing %s failed : %v", netAddr, err)
  } 

  return tdb.NewTrovian(conn, bucket)
}

//================================================================//
// newScanner
//================================================================//
func newScanner(reader io.Reader) scanner.Scanner {
  var s scanner.Scanner
  s.Init(reader)
  s.Error = func(s *scanner.Scanner, errmsg string) {
    logger.Errorf("scanner error : %s", errmsg)
  }
  s.Whitespace ^= 1<<'\t' | 1<<'\n' // don't skip tabs and new lines
  s.Mode ^= scanner.SkipComments
  return s
}

//================================================================//
// newStreamClient
//================================================================//
func newStreamClient(rw Runware) (StreamClient, error) {
  if !rw.HasKeys("StreamClient","JobId") {
    return StreamClient{}, fmt.Errorf("one or more required parameters StreamClient and JobId are undefined")
  }
  jobId := rw.String("JobId")
  req := rw.SubNode("StreamClient")
  if !req.HasKeys("StreamAddr") {
    return StreamClient{}, fmt.Errorf("StreamClient.StreamAddr is a required parameter")
  }
  streamAddr := req.String("StreamAddr")
  client,err := stm.NewStreamClient(streamAddr, jobId)
  if err != nil {
    return StreamClient{}, err
  }
  return *client, err
}

//================================================================//
// newTokenic
//================================================================//
func newTokenic(rw Runware) (Tokenic, error) {
  if !rw.HasKeys("CacheSize") {
    return Tokenic{}, fmt.Errorf("CacheSize is a required parameter")
  }
  cache := LineCache{
    this: []string{},
    maxsize: rw.Int("CacheSize"),
  }
  if cache.maxsize < 0 {
    return Tokenic{}, fmt.Errorf("line cache max size must be >= 0")
  } else if cache.maxsize > 128 {
    return Tokenic{}, fmt.Errorf("nominated line cache max size |%d| exceeds the allowed upper limit of 128", cache.maxsize)
  }
  return Tokenic{
    recent: cache,
  }, nil
}

//----------------------------------------------------------------//
// newVarDec
//----------------------------------------------------------------//
func newVarDec(indentFactor, indentSize int, rw Runware) VarDec {
  cache := LineCache{
    this: []string{},
  }
  return VarDec{
    cache: cache,
    dbPrefix: rw.String("DbPrefix"),
    indentFactor: indentFactor,
    indentSize: indentSize,
  }
}

//----------------------------------------------------------------//
// newVdParser
//----------------------------------------------------------------//
func newVdParser(rw Runware) (VdParser, error) {
  tokenic, err := newTokenic(rw.SubNode("Tokenic"))
  return VdParser{
    Tokenic: tokenic,
    varDec: newVarDec(1, 2, rw.SubNode("DefaultValue")),
  }, err
}

//================================================================//
// getSectional
//================================================================//
func getSectional(id rune) (Sectional, error) {
  switch id {
  case 'A':
    return Sectional(sectionalA), nil
  default:
    return nil, fmt.Errorf("unknown Sectional kind : %v", id)
  }
}

//----------------------------------------------------------------//
// Run
//----------------------------------------------------------------//
type CodeGen func(Runware) error
func (c CodeGen) Run(rw Runware) ApiRecord {
  err := c(rw)
  result := ApiResult{}
  return result.CheckErr(err, 400)
}

func (c CodeGen) String() string {
  return "StreamGen"
}

var StreamGen CodeGen = func(req_ Runware) error {
//  logger.Infof("running a new StreamGen instance ...")

  req = req_
  
  var err error
  client, err = newStreamClient(req)
  if err != nil {
    return err
  }

  reader, err := os.Open(req.String("InputFile"))
  if err != nil {
    return err
  }

  spec := req.SubNode("Streamium")
  spec.Set("Action","Init")
  req.Delete("Streamium")
  response := client.Request(spec)
//  logger.Debugf("got Init request response : %v", response.Parameter().Value().AsInterface())
  if response.AppFailed() {
    return response.Unwrap()
  } else if response.Parameter().String() != "Resume" {
    return fmt.Errorf("Streamium Init action did not succeed - got advice : %s", response.Parameter().String())
  }

  pr, err = newVdParser(req)
  if err != nil {
    return err
  }

  err = pr.start()
  if err != nil {
    return err
  }

  sx, err = getSectional('A')
  if err != nil {
    return err
  }

  pos := [2]scanner.Position{}
  pos[0] = scanner.Position{
    Line: 1,
    Column: 1}

  s := newScanner(reader)
  sd = &ScanData{}

  defer reader.Close()
  
  for sd.trune = s.Scan(); ; sd.trune = s.Scan() {
    if sd.trune == scanner.EOF {
      pr.complete = true
      sx.UseLine()
//      logger.Infof("!!! sectional program is now complete !!!")
      break
    }
    pos[1] = s.Pos()
    sd.fmtWidth = pos[1].Column - pos[0].Column
    sd.Token = s.TokenText()
    err = pr.useToken()
    if err != nil {
      logger.Error(err)
      return err
    } else if pr.complete {
//      logger.Infof("!!! sectional program is now complete !!!")
      break
    }
    sd.LineNum = pos[1].Line
    pos[0] = pos[1]
  }

  return nil
}