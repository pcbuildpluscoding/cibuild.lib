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
    client.AddLine(pr.line)
  }
  return nil, nil
}

//================================================================//
// sectionalC
//================================================================//
var sectionalC Sectional = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func newRunCommand") {
    pr.setMatcher(2)
//    logger.Debugf("$$$$$$$$$$$ newRunCommand declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("newRunCommand", "NewRunCommand",1).String()
    client.AddLine(pr.line)
    return sectionalD, nil
  }
  return nil, nil
}

//================================================================//
// SectionalD
//================================================================//
var sectionalD = func() (Sectional, error) {
  if pr.matches("}") {
    client.AddLine(pr.line)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "newRunCommand")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalE, nil
  }
  client.AddLine(pr.line)
  return nil, nil
}

//================================================================//
// SectionalE
//================================================================//
var sectionalE = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func runAction") {
//    logger.Debugf("$$$$$$$$$$$ runAction declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    // add comments above the function header
    for _, line := range pr.recent.reversed() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
    }
    client.AddLine(pr.line)
    content := `
  rc, err := rcw.ParseCommand(cmd, args)
  if err != nil {
    return err
  }
`
    client.AddLine(content)
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
  if err := rc.Unwrap(true); err != nil {
    return err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ createContainer function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "runAction")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalG, nil
  }
  pr.parseLine()
  switch xline := pr.xline(); {
  case xline.Contains("loadNetworkFlags"),
       xline.Contains("createContainer"):
    pr.line = xline.Replace("cmd","rc",1).String()
  }
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalG
//================================================================//
var sectionalG = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func createContainer") {
//    logger.Debugf("$$$$$$$$$$$ createContainer declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    // add comments above the function header
    for _, line := range pr.recent.reversed() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
    }
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
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return nil, nil, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ createContainer function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "createContainer")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalI, nil
  }
  pr.parseLine()
  switch xline := pr.xline(); {
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
      pr.line = xline.Replace("cmd","rc",1).String()
    case xline.Contains("withNerdctlOCIHook"):
      pr.line = xline.Replace("withNerdctlOCIHook(cmd, id)","withCntrizeOCIHook(id, dataStore, globalOptions)",1).String()
    }
    pr.putLine()
  }
  return nil, nil
}

//================================================================//
// SectionalI
//================================================================//
var sectionalI = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func processPullCommandFlagsInRun") {
//    logger.Debugf("$$$$$$$$$$$ processPullCommandFlagsInRun declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    // add comments above the function header
    for _, line := range pr.recent.reversed() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
    }
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalJ, nil
  }
  return nil, nil
}

//================================================================//
// SectionalJ
//================================================================//
var sectionalJ = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return types.ImagePullOptions{}, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ processPullCommandFlagsInRun function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "processPullCommandFlagsInRun")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalK, nil
  }
  pr.parseLine()
  switch xline := pr.xline(); {
  case xline.Contains("processImageVerifyOptions"):
    pr.line = xline.Replace("cmd","rc",1).String()
  case xline.Contains("cmd.OutOrStdout"):
    pr.line = xline.Replace("cmd.OutOrStdout()","os.Stdout",1).String()
  case xline.Contains("cmd.ErrOrStderr"):
    pr.line = xline.Replace("cmd.ErrOrStderr()","os.Stderr",1).String()
  }
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalK
//================================================================//
var sectionalK = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func generateRootfsOpts") {
    pr.setMatcher(3)
//    logger.Debugf("$$$$$$$$$$$ generateRootfsOpts declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalL, nil
  }
  return nil, nil
}

//================================================================//
// SectionalL
//================================================================//
var sectionalL = func() (Sectional, error) {
  if pr.matches("}") {
    client.AddLine(pr.line)
    finalVdec := `
  if err = rc.Unwrap(true); err != nil {
    return nil, nil, nil, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ generateRootfsOpts function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "generateRootfsOpts")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalM, nil
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
// SectionalM
//================================================================//
var sectionalM = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func withContainerLabels") {
//    logger.Debugf("$$$$$$$$$$$ withContainerLabels declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalN, nil
  }
  return nil, nil
}

//================================================================//
// SectionalN
//================================================================//
var sectionalN = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
//    logger.Debugf("$$$$$$$ withContainerLabels function end at line : %d $$$$$$$", sd.LineNum)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "withContainerLabels")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalO, nil
  }
  switch xline := pr.xline(); {
  case xline.Contains("readKVStringsMapfFromLabel"):
    pr.line = xline.Replace("cmd","rc",1).String()
  }
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalO
//================================================================//
var sectionalO = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func readKVStringsMapfFromLabel") {
//    logger.Debugf("$$$$$$$$$$$ readKVStringsMapfFromLabel declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalP, nil
  }
  return nil, nil
}

//================================================================//
// SectionalP
//================================================================//
var sectionalP = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return nil, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ readKVStringsMapfFromLabel function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "readKVStringsMapfFromLabel")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalQ, nil
  }
  pr.parseLine()
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalQ
//================================================================//
var sectionalQ = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func parseKVStringsMapFromLogOpt") {
//    logger.Debugf("$$$$$$$$$$$ parseKVStringsMapFromLogOpt declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    // add comments above the function header
    for _, line := range pr.recent.reversed() {
      if strings.HasPrefix(line, "//") {
        client.AddLine(line)
      }
    }
    pr.line = pr.xline().Replace("cmd *cobra.Command", "rc *Rucware",1).String()
    client.AddLine(pr.line)
    return sectionalR, nil
  }
  return nil, nil
}

//================================================================//
// SectionalR
//================================================================//
var sectionalR = func() (Sectional, error) {
  if pr.line == "}" {
    client.AddLine(pr.line)
    finalVdec := `
  if err := rc.Unwrap(true); err != nil {
    return nil, err
  }
`
    pr.varDec.add(finalVdec)
//    logger.Debugf("$$$$$$$ parseKVStringsMapFromLogOpt function end at line : %d $$$$$$$", sd.LineNum)
    client.InsertLines("// variable-declarations", pr.varDec.flush()...)
    req.Set("Action","WriteSection")
    req.Set("SectionName", "parseKVStringsMapFromLogOpt")
    resp := client.StreamReq(req)
//    logger.Debugf("got resume after streaming response : %v", resp.Parameter().Value().AsInterface())
    if err := checkResponse(resp, "resume after streaming"); err != nil {
      return nil, err
    }
    return sectionalS, nil
  }
  pr.parseLine()
  pr.putLine()
  return nil, nil
}

//================================================================//
// SectionalS
//================================================================//
var sectionalS = func() (Sectional, error) {
  if strings.HasPrefix(pr.line, "func withStop") {
//    logger.Debugf("$$$$$$$$$$$ withStop declaration FOUND at line : %d $$$$$$$$$$$", sd.LineNum)
    client.AddLine(pr.line)
    return sectionalT, nil
  }
  return nil, nil
}

//================================================================//
// SectionalT
//================================================================//
var sectionalT = func() (Sectional, error) {
  if pr.complete {
    if pr.line != "" {
      client.AddLine(pr.line)
    }
//    logger.Debugf("$$$$$$$ END OF FILE $$$$$$$")
    req.Set("Action","WriteSection")
    req.Set("SectionName", "withStop")
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