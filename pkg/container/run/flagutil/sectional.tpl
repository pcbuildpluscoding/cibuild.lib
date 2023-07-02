package create

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
    if resp.Parameter().String() != "Ok" {
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
  if strings.HasPrefix(pr.Line, "import") {
    logger.Debugf("$$$$$$$$$$$ import declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "import")
    resp := client.Request(req)
    logger.Debugf("got SectionName=import response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=import"); err != nil {
      logger.Error(err)
      return nil, err
    }
    return sectionalB, nil
  } 
  return nil, nil
}

//================================================================//
// sectionalB
//================================================================//
var sectionalB Sectional = func() (Sectional, error) {
  if pr.Line == ")" {
    logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Suspend_For_Streaming")
    resp := client.Request(req)
    logger.Debugf("got Suspend_For_Streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "Suspend_For_Streaming"); err != nil {
      return nil, err
    }
    resp = client.StreamReq()
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalC, nil
  } 
  switch xline := pr.XLine(); {
  case xline.Contains("spf13/cobra"):
  default:
    client.AddLine(pr.Line)
  }
  return nil, nil
}

//================================================================//
// SectionalC
//================================================================//
var sectionalC = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func processImageSignOptions") {
    logger.Debugf("$$$$$$$$$$$ processImageSignOptions declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "processImageSignOptions")
    resp := client.Request(req)
    logger.Debugf("got SectionName=processImageSignOptions response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=processImageSignOptions"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "cspec *CntrSpec",1).String()
    pr.Line = pr.XLine().Replace("opt types.ImageSignOptions, err error", "types.ImageSignOptions, error",1).String()
    client.AddLine(pr.Line, pr.varDec.FormatLine("var opt types.ImageSignOptions"))
    return sectionalD, nil
  }
  return nil, nil
}

//================================================================//
// SectionalD
//================================================================//
var sectionalD = func() (Sectional, error) {
  if pr.Line == "}" {
    client.AddLine(pr.Line)
    finalVdec := `
  if err = cspec.Err(); err != nil {
    return
  }
  cspec.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ processImageSignOptions function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.Flush()...)
    req.Set("Action","Suspend_For_Streaming")
    resp := client.Request(req)
    logger.Debugf("got Suspend_For_Streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "Suspend_For_Streaming"); err != nil {
      return nil, err
    }
    resp = client.StreamReq()
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    logger.Debugf("$$$$$$$$$$$$$$$$ vardec cache is empty ?? : %v $$$$$$$$$$$$$$$", pr.varDec.CacheIsEmpty())
    return sectionalE, nil
  } else {
    pr.parseLine("processImageSignOptions")
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalE
//================================================================//
var sectionalE = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func processImageVerifyOptions") {
    logger.Debugf("$$$$$$$$$$$ processImageVerifyOptions declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "processImageVerifyOptions")
    resp := client.Request(req)
    logger.Debugf("got SectionName=processImageVerifyOptions response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=processImageVerifyOptions"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "cspec *CntrSpec",1).String()
    pr.Line = pr.XLine().Replace("opt types.ImageVerifyOptions, err error", "types.ImageVerifyOptions, error",1).String()
    client.AddLine(pr.Line, pr.varDec.FormatLine("var opt types.ImageVerifyOptions"))
    pr.varDec.firstParam = true
    return sectionalF, nil
  }
  return nil, nil
}

//================================================================//
// SectionalF
//================================================================//
var sectionalF = func() (Sectional, error) {
  if pr.Line == "}" {
    client.AddLine(pr.Line)
    finalVdec := `
  if err = cspec.Err(); err != nil {
    return
  }
  cspec.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ processImageVerifyOptions function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.Flush()...)
    req.Set("Action","Suspend_For_Streaming")
    resp := client.Request(req)
    logger.Debugf("got Suspend_For_Streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "Suspend_For_Streaming"); err != nil {
      return nil, err
    }
    resp = client.StreamReq()
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalG, nil
  } else {
    pr.parseLine("processImageVerifyOptions")
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalG
//================================================================//
var sectionalG = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func processRootCmdFlags") {
    logger.Debugf("$$$$$$$$$$$ processRootCmdFlags declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "processRootCmdFlags")
    resp := client.Request(req)
    logger.Debugf("got SectionName=processRootCmdFlags response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=processRootCmdFlags"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "cspec *CntrSpec",1).String()
    client.AddLine(pr.Line)
    return sectionalH, nil
  }
  return nil, nil
}

//================================================================//
// SectionalH
//================================================================//
var sectionalH = func() (Sectional, error) {
  if pr.Complete {
    if pr.Line != "" {
      client.AddLine(pr.Line)
    }
    finalVdec := `
  if err := cspec.Err(); err != nil {
    return types.GlobalCommandOptions{}, err
  }
  cspec.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ processRootCmdFlags function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.Flush()...)
    req.Set("Action","Suspend_For_Streaming")
    resp := client.Request(req)
    logger.Debugf("got Suspend_For_Streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "Suspend_For_Streaming"); err != nil {
      return nil, err
    }
    resp = client.StreamReq()
    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
  } else {
    pr.parseLine("processRootCmdFlags")
    pr.putLine()
  }
  return nil, nil
}

