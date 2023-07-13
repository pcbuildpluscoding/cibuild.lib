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
    client.AddLine(pr.line)
    return sectionalB, nil
  } 
  return nil, nil
}

//================================================================//
// SectionalB
//================================================================//
var sectionalB = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func setPlatformOptions") {
    req.Set("Action","WriteSection")
    req.Set("SectionName", "import")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    //    logger.Debugf("$$$$$$$$$$$ setPlatformOptions declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalC, nil
  }
  client.AddLine(pr.line)
  return nil, nil
}

//================================================================//
// SectionalC
//================================================================//
var sectionalC = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return nil, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ setPlatformOptions function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "setPlatformOptions")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalD, nil
  }
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
  return nil, nil
}

//================================================================//
// SectionalD
//================================================================//
var sectionalD = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func generateNamespaceOpts") {
//    logger.Debugf("$$$$$$$$$$$ generateNamespaceOpts declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    // add comments above the function header
    for _, line := range pr.recent.flush() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
    }
    client.AddLine(pr.line)
    return sectionalE, nil
  }
  return nil, nil
}

//================================================================//
// SectionalE
//================================================================//
var sectionalE = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return nil, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ generateNamespaceOpts function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "generateNamespaceOpts")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalF, nil
  }
  pr.parseLine()
  switch xline := pr.xline(); {
  case xline.Contains("cobra.Command"):
    pr.line = xline.Replace("cmd *cobra.Command", "rc *Rucware",1).String()
  }
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalF
//================================================================//
var sectionalF = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func setOOMScoreAdj") {
//    logger.Debugf("$$$$$$$$$$$ setOOMScoreAdj declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalG, nil
  }
  return nil, nil
}

//================================================================//
// SectionalG
//================================================================//
var sectionalG = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return opts, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ setOOMScoreAdj function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "setOOMScoreAdj")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalH, nil
  }
  pr.parseLine()
  switch xline := pr.xline(); {
  case xline.Contains("processPullCommandFlagsInRun"):
    pr.line = xline.Replace("cmd","rc",1).String()
  }
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalH
//================================================================//
var sectionalH = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func withOOMScoreAdj") {
//    logger.Debugf("$$$$$$$$$$$ withOOMScoreAdj declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    client.AddLine(pr.line)
    return sectionalI, nil
  }
  return nil, nil
}

//================================================================//
// SectionalI
//================================================================//
var sectionalI = func() (Sectional, error) {
  if pr.complete {
    if pr.line != "" {
      client.AddLine(pr.line)
    }
//    logger.Debugf("$$$$$$$ END OF FILE $$$$$$$")
    req.Set("Action","WriteSection")
    req.Set("SectionName", "withOOMScoreAdj")
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
  pr.putLine()
  return nil, nil
}