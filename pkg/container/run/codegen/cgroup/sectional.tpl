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
    client.AddLine(pr.Line)
    return sectionalB, nil
  } 
  return nil, nil
}

//================================================================//
// sectionalB
//================================================================//
var sectionalB Sectional = func() (Sectional, error) {
  if pr.Line == "}" {
    client.AddLine(pr.Line)
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
    logger.Debugf("$$$$$$$$$$$ import reference spf13/cobra is found $$$$$$$$$$$$")
  default:
    client.AddLine(pr.Line)
  }
  return nil, nil
}

//================================================================//
// SectionalC
//================================================================//
var sectionalC = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func generateCgroupOpts") {
    logger.Debugf("$$$$$$$$$$$ generateCgroupOpts declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "generateCgroupOpts")
    resp := client.Request(req)
    logger.Debugf("got SectionName=generateCgroupOpts response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=generateCgroupOpts"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "rc *Runcare",1).String()
    client.AddLine(pr.Line)
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
  if err := rc.Err(); err != nil {
    return nil, err
  }
  rc.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ generateCgroupOpts function end at line : %d $$$$$$$", sd.LineNum)
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
    pr.parseLine()
    switch xline := pr.XLine(); {
		case xline.Contains("generateCgroupPath"):
      pr.Line = xline.Replace("cmd","rc",1).String()
    }
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalE
//================================================================//
var sectionalE = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func generateCgroupPath") {
    logger.Debugf("$$$$$$$$$$$ generateCgroupPath declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "generateCgroupPath")
    resp := client.Request(req)
    logger.Debugf("got SectionName=generateCgroupPath response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=generateCgroupPath"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "rc *Runcare",1).String()
    client.AddLine(pr.Line)
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

		logger.Debugf("$$$$$$$ generateCgroupPath function end at line : %d $$$$$$$", sd.LineNum)
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
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalG
//================================================================//
var sectionalG = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func parseDevice") {
    logger.Debugf("$$$$$$$$$$$ parseDevice declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "parseDevice")
    resp := client.Request(req)
    logger.Debugf("got SectionName=parseDevice response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=parseDevice"); err != nil {
      logger.Error(err)
      return nil, err
    }
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
    logger.Debugf("$$$$$$$ END OF FILE $$$$$$$")
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
    req.Set("Action","Complete")
    resp = client.Request(req)
    logger.Debugf("got Complete response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "Complete"); err != nil {
      return nil, err
    }
  } else {
    pr.putLine()
  }
  return nil, nil
}