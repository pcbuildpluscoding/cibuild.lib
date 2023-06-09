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
//    logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND at line : %d $$$$$$$$$$$", sd.lineNum)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "import")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalC, nil
  } 
  switch xline := pr.xline(); {
  case xline.Contains("spf13/cobra"):
//    logger.Debugf("$$$$$$$$$$$ import reference spf13/cobra is found $$$$$$$$$$$$")
  default:
    client.AddLine(pr.line)
  }
  return nil, nil
}

//================================================================//
// SectionalC
//================================================================//
var sectionalC = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func loadNetworkFlags") {
    logger.Debugf("$$$$$$$$$$$ loadNetworkFlags declaration FOUND at line : %d $$$$$$$$$$$", sd.lineNum)
    // add comments above the function header
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
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
    logger.Debugf("$$$$$$$ END OF FILE $$$$$$$")
    if pr.line != "" {
      client.AddLine(pr.line)
    }
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return netOpts, err
  }
`
    pr.varDec.add(finalVdec)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "loadNetworkFlags")
    resp := client.StreamReq(req)
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    logger.Debugf("$$$$$$$$$$$$ network parsing is complete $$$$$$$$$$$$4")
    req.Set("Action","Complete")
    resp = client.Request(req)
    logger.Debugf("got Complete response : %v", resp.Parameter().Value().AsInterface())
    err := checkResponse(resp, "Complete")
    return nil, err
  }
  pr.parseLine()
  pr.putLine()
  return nil, nil
}
