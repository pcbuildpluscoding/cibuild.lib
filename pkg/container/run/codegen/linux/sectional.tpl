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
//    logger.Debugf("$$$$$$$$$$$ import declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","SectionStart")
    req.Set("SectionName", "import")
    resp := client.Request(req)
//    logger.Debugf("got SectionName=import response : %v", resp.Parameter().Value().AsInterface())
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
  if pr.line == "}" {
    client.AddLine(pr.line)
//    logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","WriteStream")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalC, nil
  } 
  switch xline := pr.xline(); {
  case xline.Contains("containerd/pkg/cap"),
       xline.Contains("spf13/cobra"):
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
  if strings.HasPrefix(pr.line, "func setPlatformOptions") {
//    logger.Debugf("$$$$$$$$$$$ setPlatformOptions declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","SectionStart")
    req.Set("SectionName", "setPlatformOptions")
    resp := client.Request(req)
//    logger.Debugf("got SectionName=setPlatformOptions response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=setPlatformOptions"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rw *Rucware",1).String()
    client.AddLine(pr.line)
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
  if err := rw.Unwrap(true); err != nil {
    return nil, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ setPlatformOptions function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteStream")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalE, nil
  } else {
    pr.parseLine()
    switch xline := pr.xline(); {
    case xline.Contains("generateCgroupOpts"),
          xline.Contains("readKVStringsMapfFromLabel"),
          xline.Contains("generateUlimitsOpts"),
          xline.Contains("generateNamespaceOpts"),
          xline.Contains("setOOMScoreAdj"):
      pr.line = xline.Replace("cmd","rc",1).String()
    }
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalE
//================================================================//
var sectionalE = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func generateNamespaceOpts") {
//    logger.Debugf("$$$$$$$$$$$ generateNamespaceOpts declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","SectionStart")
    req.Set("SectionName", "generateNamespaceOpts")
    resp := client.Request(req)
//    logger.Debugf("got SectionName=generateNamespaceOpts response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=generateNamespaceOpts"); err != nil {
      logger.Error(err)
      return nil, err
    }
    // add comments above the function header
    for _, line := range pr.recent.reversed() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
    }
    client.AddLine(pr.line)
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
  if err := rw.Unwrap(true); err != nil {
    return nil, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ generateNamespaceOpts function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteStream")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalG, nil
  } else {
    pr.parseLine()
    switch xline := pr.xline(); {
    case xline.Contains("cobra.Command"):
      pr.line = xline.Replace("cmd *cobra.Command", "rw *Rucware",1).String()
    }
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalG
//================================================================//
var sectionalG = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func setOOMScoreAdj") {
//    logger.Debugf("$$$$$$$$$$$ setOOMScoreAdj declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","SectionStart")
    req.Set("SectionName", "setOOMScoreAdj")
    resp := client.Request(req)
//    logger.Debugf("got SectionName=setOOMScoreAdj response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=setOOMScoreAdj"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rw *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalH, nil
  }
  return nil, nil
}

//================================================================//
// SectionalH
//================================================================//
var sectionalH = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err := rw.Unwrap(true); err != nil {
    return opts, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ setOOMScoreAdj function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteStream")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalI, nil
  } else {
    pr.parseLine()
    switch xline := pr.xline(); {
    case xline.Contains("processPullCommandFlagsInRun"):
      pr.line = xline.Replace("cmd","rc",1).String()
    }
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalI
//================================================================//
var sectionalI = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func withOOMScoreAdj") {
//    logger.Debugf("$$$$$$$$$$$ withOOMScoreAdj declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","SectionStart")
    req.Set("SectionName", "withOOMScoreAdj")
    resp := client.Request(req)
//    logger.Debugf("got SectionName=withOOMScoreAdj response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=withOOMScoreAdj"); err != nil {
      logger.Error(err)
      return nil, err
    }
    client.AddLine(pr.line)
    return sectionalJ, nil
  }
  return nil, nil
}

//================================================================//
// SectionalJ
//================================================================//
var sectionalJ = func() (Sectional, error) {
  if pr.complete {
    if pr.line != "" {
      client.AddLine(pr.line)
    }
//    logger.Debugf("$$$$$$$ END OF FILE $$$$$$$")
    req.Set("Action","WriteStream")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    req.Set("Action","Complete")
    resp = client.Request(req)
//    logger.Debugf("got Complete response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "Complete"); err != nil {
      return nil, err
    }
  } else {
    pr.putLine()
  }
  return nil, nil
}