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
    req.Set("Action","SectionStart")
    req.Set("SectionName", "import")
    resp := client.Request(req)
    logger.Debugf("got SectionName=import response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=import"); err != nil {
      logger.Error(err)
      return nil, err
    }
    client.AddLine(pr.line)
    return sectionalB, nil
  } 
  return nil, nil
}

//================================================================//
// sectionalB
//================================================================//
var sectionalB Sectional = func() (Sectional, error) {
  if pr.line == ")" {
    client.AddLine(pr.line)
    logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","WriteStream")
    resp := client.StreamReq(req)
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalC, nil
  } 
  switch xline := pr.xline(); {
  case xline.Contains("spf13/cobra"):
    logger.Debugf("$$$$$$$$$$$ import reference spf13/cobra is found $$$$$$$$$$$$")
  default:
    client.AddLine(pr.line)
  }
  return nil, nil
}

//================================================================//
// SectionalC
//================================================================//
var sectionalC = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func generateUlimitsOpts") {
    logger.Debugf("$$$$$$$$$$$ generateUlimitsOpts declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","SectionStart")
    req.Set("SectionName", "generateUlimitsOpts")
    resp := client.Request(req)
    logger.Debugf("got SectionName=generateUlimitsOpts response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=generateUlimitsOpts"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Runcare",1).String()
    client.AddLine(pr.line)
    return sectionalD, nil
  }
  return nil, nil
}

//================================================================//
// SectionalD
//================================================================//
var sectionalD = func() (Sectional, error) {
  if pr.complete {
    if pr.line != "" {
      client.AddLine(pr.line)
    }
    finalVdec := `
  if err := rc.Err(); err != nil {
    return nil, err
  }
  rc.ErrReset()
`
    pr.varDec.add(finalVdec)
    logger.Debugf("$$$$$$$ END OF FILE $$$$$$$")
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteStream")
    resp := client.StreamReq(req)
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    req.Set("Action","Complete")
    resp = client.Request(req)
    logger.Debugf("got Complete response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "Complete"); err != nil {
      return nil, err
    }
  } else {
    pr.parseLine()
    pr.putLine()
  }
  return nil, nil
}

