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
//    logger.Debugf("$$$$$$$$$$$ import declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    return sectionalB, nil
  } 
  return nil, nil
}

//================================================================//
// sectionalB
//================================================================//
var sectionalB Sectional = func() (Sectional, error) {
  if pr.line == ")" {
//    logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
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
  default:
    client.AddLine(pr.line)
  }
  return nil, nil
}

//================================================================//
// SectionalC
//================================================================//
var sectionalC = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func processImageSignOptions") {
//    logger.Debugf("$$$$$$$$$$$ processImageSignOptions declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    pr.line = pr.xline().Replace("opt types.ImageSignOptions, err error", "types.ImageSignOptions, error",1).String()
    client.AddLine(pr.line, pr.varDec.formatLine("var opt types.ImageSignOptions"))
    return sectionalD, nil
  }
  return nil, nil
}

//================================================================//
// SectionalD
//================================================================//
var sectionalD = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err = rc.Unwrap(true); err != nil {
    return
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ processImageSignOptions function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "processImageSignOptions")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalE, nil
  }
  pr.parseLine("processImageSignOptions")
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalE
//================================================================//
var sectionalE = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func processImageVerifyOptions") {
//    logger.Debugf("$$$$$$$$$$$ processImageVerifyOptions declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    pr.line = pr.xline().Replace("opt types.ImageVerifyOptions, err error", "types.ImageVerifyOptions, error",1).String()
    client.AddLine(pr.line, pr.varDec.formatLine("var opt types.ImageVerifyOptions"))
    pr.varDec.firstParam = true
    return sectionalF, nil
  }
  return nil, nil
}

//================================================================//
// SectionalF
//================================================================//
var sectionalF = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err = rc.Unwrap(true); err != nil {
    return
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ processImageVerifyOptions function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "processImageVerifyOptions")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalG, nil
  }
  pr.parseLine("processImageVerifyOptions")
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalG
//================================================================//
var sectionalG = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func processRootCmdFlags") {
//    logger.Debugf("$$$$$$$$$$$ processRootCmdFlags declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalH, nil
  }
  return nil, nil
}

//================================================================//
// SectionalH
//================================================================//
var sectionalH = func() (Sectional, error) {
  if pr.complete {
    if pr.line != "" {
      client.AddLine(pr.line)
    }
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return types.GlobalCommandOptions{}, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ END OF FILE $$$$$$$")
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "processRootCmdFlags")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    req.Set("Action","Complete")
    resp = client.Request(req)
//    logger.Debugf("got Complete response : %v", resp.Parameter().Value().AsInterface())
    err := checkResponse(resp, "Complete")
    return nil, err
  }
  pr.parseLine("processRootCmdFlags")
  pr.putLine()
  return nil, nil
}