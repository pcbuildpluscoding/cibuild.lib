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
  case xline.Contains("containerd/console"),
			 xline.Contains("nerdctl/pkg/consoleutil"),
			 xline.Contains("nerdctl/pkg/defaults"),
			 xline.Contains("nerdctl/pkg/errutil"),
			 xline.Contains("nerdctl/pkg/netutil"),
			 xline.Contains("nerdctl/pkg/signalutil"),
			 xline.Contains("nerdctl/pkg/taskutil"),
			 xline.Contains("spf13/cobra"):
  case xline.Contains("encoding/json"):
    client.AddLine(`  "encoding/base64"`)
    fallthrough
  default:
    client.AddLine(pr.Line)
  }
  return nil, nil
}

//================================================================//
// SectionalC
//================================================================//
var sectionalC = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func createContainer") {
    logger.Debugf("$$$$$$$$$$$ createContainer declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "createContainer")
    resp := client.Request(req)
    logger.Debugf("got SectionName=createContainer response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=createContainer"); err != nil {
      logger.Error(err)
      return nil, err
    }
    // add comments above the function header
    for _, line := range pr.recent.reversed() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
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
    return nil, nil, err
  }
  rc.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ createContainer function end at line : %d $$$$$$$", sd.LineNum)
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
    case xline.Contains("var umask string"):
    case xline.Contains("var pidFile string"):
    default:
      switch {
      case xline.Contains("setPlatformOptions"),
           xline.Contains("generateRootfsOpts"),
           xline.Contains("generateMountOpts"),
           xline.Contains("parseKVStringsMapFromLogOpt"),
           xline.Contains("generateRuntimeCOpts"),
           xline.Contains("withContainerLabels"):
        pr.Line = xline.Replace("cmd","rc",1).String()
      case xline.Contains("withNerdctlOCIHook"):
        pr.Line = xline.Replace("withNerdctlOCIHook(cmd, id)","WithCntrizeOCIHook(id, dataStore, rc)",1).String()
      }
      pr.putLine()
    }
  }
  return nil, nil
}

//================================================================//
// SectionalE
//================================================================//
var sectionalE = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func processPullCommandFlagsInRun") {
    logger.Debugf("$$$$$$$$$$$ processPullCommandFlagsInRun declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "processPullCommandFlagsInRun")
    resp := client.Request(req)
    logger.Debugf("got SectionName=processPullCommandFlagsInRun response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=processPullCommandFlagsInRun"); err != nil {
      logger.Error(err)
      return nil, err
    }
    // add comments above the function header
    for _, line := range pr.recent.reversed() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
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
    finalVdec := `
  if err := rc.Err(); err != nil {
    return types.ImagePullOptions{}, err
  }
  rc.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ processPullCommandFlagsInRun function end at line : %d $$$$$$$", sd.LineNum)
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
    pr.parseLine()
    switch xline := pr.XLine(); {
    case xline.Contains("processImageVerifyOptions"):
      pr.Line = xline.Replace("cmd","rc",1).String()
    case xline.Contains("cmd.OutOrStdout"):
      pr.Line = xline.Replace("cmd.OutOrStdout()","os.Stdout",1).String()
    case xline.Contains("cmd.ErrOrStderr"):
      pr.Line = xline.Replace("cmd.ErrOrStderr()","os.Stderr",1).String()
    }
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalG
//================================================================//
var sectionalG = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func generateRootfsOpts") {
    pr.SetMatcher(3)
    logger.Debugf("$$$$$$$$$$$ generateRootfsOpts declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "generateRootfsOpts")
    resp := client.Request(req)
    logger.Debugf("got SectionName=generateRootfsOpts response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=generateRootfsOpts"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "rc *Runcare",1).String()
    client.AddLine(pr.Line)
    return sectionalH, nil
  }
  return nil, nil
}

//================================================================//
// SectionalH
//================================================================//
var sectionalH = func() (Sectional, error) {
  if pr.Matches("}") {
    client.AddLine(pr.Line)
    finalVdec := `
  if err = rc.Err(); err != nil {
    return nil, nil, nil, err
  }
  rc.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ generateRootfsOpts function end at line : %d $$$$$$$", sd.LineNum)
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
    return sectionalI, nil
  } else {
    pr.parseLine()
    switch xline := pr.XLine(); {
    case xline.Contains("processPullCommandFlagsInRun"):
      pr.Line = xline.Replace("cmd","rc",1).String()
    }
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalI
//================================================================//
var sectionalI = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func withContainerLabels") {
    logger.Debugf("$$$$$$$$$$$ withContainerLabels declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "withContainerLabels")
    resp := client.Request(req)
    logger.Debugf("got SectionName=withContainerLabels response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=withContainerLabels"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "rc *Runcare",1).String()
    client.AddLine(pr.Line)
    return sectionalJ, nil
  }
  return nil, nil
}

//================================================================//
// SectionalJ
//================================================================//
var sectionalJ = func() (Sectional, error) {
  if pr.Line == "}" {
    client.AddLine(pr.Line)
    logger.Debugf("$$$$$$$ withContainerLabels function end at line : %d $$$$$$$", sd.LineNum)
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
    return sectionalK, nil
  } else {
    switch xline := pr.XLine(); {
    case xline.Contains("readKVStringsMapfFromLabel"):
      pr.Line = xline.Replace("cmd","rc",1).String()
    }
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalK
//================================================================//
var sectionalK = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func readKVStringsMapfFromLabel") {
    logger.Debugf("$$$$$$$$$$$ readKVStringsMapfFromLabel declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "readKVStringsMapfFromLabel")
    resp := client.Request(req)
    logger.Debugf("got SectionName=readKVStringsMapfFromLabel response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=readKVStringsMapfFromLabel"); err != nil {
      logger.Error(err)
      return nil, err
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "rc *Runcare",1).String()
    client.AddLine(pr.Line)
    return sectionalL, nil
  }
  return nil, nil
}

//================================================================//
// SectionalL
//================================================================//
var sectionalL = func() (Sectional, error) {
  if pr.Line == "}" {
    client.AddLine(pr.Line)
    finalVdec := `
  if err := rc.Err(); err != nil {
    return nil, err
  }
  rc.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ readKVStringsMapfFromLabel function end at line : %d $$$$$$$", sd.LineNum)
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
    return sectionalM, nil
  } else {
    pr.parseLine()
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalM
//================================================================//
var sectionalM = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func parseKVStringsMapFromLogOpt") {
    logger.Debugf("$$$$$$$$$$$ parseKVStringsMapFromLogOpt declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "parseKVStringsMapFromLogOpt")
    resp := client.Request(req)
    logger.Debugf("got SectionName=parseKVStringsMapFromLogOpt response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=parseKVStringsMapFromLogOpt"); err != nil {
      logger.Error(err)
      return nil, err
    }
    // add comments above the function header
    for _, line := range pr.recent.reversed() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
    }
    pr.Line = pr.XLine().Replace("cmd *cobra.Command", "rc *Runcare",1).String()
    client.AddLine(pr.Line)
    return sectionalN, nil
  }
  return nil, nil
}

//================================================================//
// SectionalN
//================================================================//
var sectionalN = func() (Sectional, error) {
  if pr.Line == "}" {
    client.AddLine(pr.Line)
    finalVdec := `
  if err := rc.Err(); err != nil {
    return nil, err
  }
  rc.ErrReset()
`
    pr.varDec.Add(finalVdec)
    logger.Debugf("$$$$$$$ parseKVStringsMapFromLogOpt function end at line : %d $$$$$$$", sd.LineNum)
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
    return sectionalO, nil
  } else {
    pr.parseLine()
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalO
//================================================================//
var sectionalO = func() (Sectional, error) {
  if strings.HasPrefix(pr.Line, "func withStop") {
    logger.Debugf("$$$$$$$$$$$ withStop declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    req.Set("Action","Section_Start")
    req.Set("SectionName", "withStop")
    resp := client.Request(req)
    logger.Debugf("got SectionName=withStop response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "SectionStart=withStop"); err != nil {
      logger.Error(err)
      return nil, err
    }
    client.AddLine(pr.Line)
    return sectionalP, nil
  }
  return nil, nil
}

//================================================================//
// SectionalP
//================================================================//
var sectionalP = func() (Sectional, error) {
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