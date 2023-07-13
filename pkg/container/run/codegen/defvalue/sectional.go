package codegen

import (
  "fmt"
  "strings"
)

var (
  pr VdParser
  sd *ScanData
  sx Sectional
  client StreamClient
  req Runware
)

//================================================================//
// Sectional
//================================================================//
type Sectional func() (Sectional, error)
func (s Sectional) UseLine() error {
  s_, err := s()
  if err != nil {
    return err
  }
  if s_ != nil {
    sx = s_
  }
  return nil
}

//----------------------------------------------------------------//
// checkResponse
//----------------------------------------------------------------//
func checkResponse(resp ApiRecord, action string) error {
  if resp.AppFailed() {
    return resp.Unwrap()
  }
  switch action {
  case "Complete":
    if resp.Parameter().String() != "EOF" {
      logger.Warnf("%s response advice != Ok - got %s instead", action, resp.Parameter().String())
    }
  default:
    if resp.Parameter().String() != "Resume" {
      // client.Close()
      return fmt.Errorf("%s response advice != Resume - got %s instead", action, resp.Parameter().String())
    }
  }
  return nil
}

//================================================================//
// sectionalA
//================================================================//
var sectionalA = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "import") {
    logger.Debugf("$$$$$$$$$$$ import declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.sectionName = "Import"
    return sectionalB, nil
  } 
  return nil, nil
}

//================================================================//
// sectionalB
//================================================================//
var sectionalB Sectional = func() (Sectional, error) {
  if pr.line == ")" {
    logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    return sectionalC, nil
  } 
  if strings.Contains(pr.line, `"github.com`) {
    switch {
    case strings.Contains(pr.line, "spf13/cobra"):
      logger.Debugf("$$$$$$$$$$$ import reference spf13/cobra is found $$$$$$$$$$$$")
    default:
      pr.parseLine()
    }
  }
  return nil, nil
}

//================================================================//
// sectionalC
//================================================================//
var sectionalC Sectional = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func setCreateFlags") {
    logger.Debugf("$$$$$$$$$$$ setCreateFlags declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.sectionName = "VarDec"
    pr.varDec.indentFactor = 2
    return sectionalD, nil
  }
  return nil, nil
}

//================================================================//
// SectionalD
//================================================================//
var sectionalD = func() (Sectional, error) {
  if pr.line == "}" {
    logger.Debugf("$$$$$$$ setCreateFlags function end at line : %d $$$$$$$", sd.LineNum)
    req.Set("SectionName", "import")
    req.Set("Action","WriteSection")
    resp := client.StreamReq(req)
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    req.Set("SectionName", "content")
    req.Set("Action","WriteSection")
    client.AddLine(pr.varDec.flush()...)
    resp = client.StreamReq(req)
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    req.Set("SectionName", "dbPrefix")
    req.Set("Action","WriteSection")
    client.AddLine(pr.varDec.formatDbPrefix(1))
    resp = client.StreamReq(req)
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalE, nil
  } 
  if pr.xline().XTrim().HasPrefix("cmd.Flags") {
    pr.parseLine()
  }
  return nil, nil
}

//================================================================//
// sectionalE
//================================================================//
var sectionalE Sectional = func() (Sectional, error) {
  if pr.complete {
    logger.Debugf("$$$$$$$ END OF FILE $$$$$$$")
    req.Set("Action","Complete")
    resp := client.Request(req)
    logger.Debugf("got Complete response : %v", resp.Parameter().Value().AsInterface())
    err := checkResponse(resp, "Complete")
    return nil, err
  }
  return nil, nil
}