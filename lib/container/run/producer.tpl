package run

import (
  "fmt"
  "strings"
  "text/scanner"

  ab "github.com/pcbuildpluscoding/apibase/std"
  elm "github.com/pcbuildpluscoding/genware/lib/element"
  han "github.com/pcbuildpluscoding/genware/lib/handler"
)


//================================================================//
// TCProvider
//================================================================//
type TCProvider struct {
  dd *DataDealer
  cache map[string]TextConsumer
  skipLineCount *int
}

//----------------------------------------------------------------//
// newEditor
//----------------------------------------------------------------//
func (p *TCProvider) newEditor(kind string) (TextConsumer, error) {
  switch kind {
  case "CopyB":
    return NewLineCopierB(p.dd, p.skipLineCount)
  case "CopyC":
    return NewLineCopierC(p.dd, p.skipLineCount)
  case "VarDec":
    return NewVDExtractor(p.dd, p.skipLineCount)
  default:
    return elm.NewLineCopierA(p.dd, p.skipLineCount)
  }
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *TCProvider) Arrange(spec Runware) error {
  if !spec.HasKeys("TextConsumerKinds") {
    return fmt.Errorf("required taskSpec property TextConsumerKinds is undefined")
  }
  elist := ab.NewErrorlist(true)
  var err error
  for _, kind := range spec.StringList("TextConsumerKinds") {
    p.cache[kind], err = p.newEditor(kind)
    elist.Add(err)
  }
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// getEditor
//----------------------------------------------------------------//
func (p *TCProvider) getEditor(kind string) (TextConsumer, error) {
  var err error
  editor, found := p.cache[kind]
  if ! found {
    editor, err = p.newEditor(kind)
    if err == nil {
      p.cache[kind] = editor
    }
  }
  return editor, err
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (p *TCProvider) skipLines(skipLineCount int) {
  *p.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *TCProvider) Start() error {
  return p.dd.Start()
}

//================================================================//
// CRProducer - Container Run Content Producer
//================================================================//
type LineParser_CRP func(*CRProducer, *string, int) LineParser_CRP
type TokenParser_CRP func(*CRProducer, *ScanData) TokenParser_CRP
type CRProducer struct {
  Component
  lineParser LineParser_CRP
  lineNum int
  lineState int
  provider TCProvider
  sectionName string
  tokenParser TokenParser_CRP
  tokenState int
}

//----------------------------------------------------------------//
// endOfSection - TODO => handle errors properly
//----------------------------------------------------------------//
func (p *CRProducer) endOfSection() {
  p.Component.EndOfSection()
  p.RemoveNext()
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *CRProducer) EditLine(line *string, lineNum int) {
  if p.lineParser != nil {
    p.lineParser = p.lineParser(p, line, lineNum)
  }
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (p *CRProducer) PutLine(line string) {
  if p.Next() != nil {
    p.Next().PutLine(line)
  }
}

//----------------------------------------------------------------//
// removeDelegate - TODO => handle errors properly
//----------------------------------------------------------------//
func (p *CRProducer) removeDelegate() {
  p.EndOfSection()
  p.RemoveNext()
}

//----------------------------------------------------------------//
// scanL0
//----------------------------------------------------------------//
func (p *CRProducer) scanL0(line *string, lineNum int) LineParser_CRP {
  switch p.sectionName {
  case "createContainer":
    switch {
    case strings.Contains(*line, "setPlatformOptions"):
      *line = strings.Replace(*line, "cmd,", "cspec,", 1)
    case strings.Contains(*line, "generateRootfsOpts"):
      *line = strings.Replace(*line, "cmd,", "cspec,", 1)
    case strings.Contains(*line, "generateMountOpts"):
      *line = strings.Replace(*line, "cmd,", "cspec,", 1)
    case strings.Contains(*line, "parseKVStringsMapFromLogOpt"):
      *line = strings.Replace(*line, "cmd,", "cspec,", 1)
    case strings.Contains(*line, "withNerdctlOCIHook"):
      *line = strings.Replace(*line, "withNerdctlOCIHook(cmd, id)", "WithCntrizeOCIHook(id, dataStore, cspec)", 1)
    case strings.Contains(*line, "generateRuntimeCOpts"):
      *line = strings.Replace(*line, "cmd,", "cspec,", 1)
    case strings.Contains(*line, "withContainerLabels"):
      *line = strings.Replace(*line, "cmd", "cspec", 1)
    }
  case "processPullCommandFlagsInRun":
    switch {
    case strings.Contains(*line, "processImageVerifyOptions"):
      *line = strings.Replace(*line, "cmd", "cspec", 1)
    case strings.Contains(*line, "cmd.OutOrStdout"):
      *line = strings.Replace(*line, "cmd.OutOrStdout()", "os.Stdout", 1)
    case strings.Contains(*line, "cmd.ErrOrStderr"):
      *line = strings.Replace(*line, "cmd.ErrOrStderr()", "os.Stderr", 1)
    }
  case "generateRootfsOpts":
    switch {
    case strings.Contains(*line, "processPullCommandFlagsInRun"):
      *line = strings.Replace(*line, "cmd", "cspec", 1)
    }
  case "withContainerLabels":
    switch {
    case strings.Contains(*line, "readKVStringsMapfFromLabel"):
      *line = strings.Replace(*line, "cmd", "cspec", 1)
    }
  }
  return (*CRProducer).scanL0
}

//----------------------------------------------------------------//
// scanT0
//----------------------------------------------------------------//
func (p *CRProducer) scanT0(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "import" && sd.TokenIndex == 0 {
      logger.Debugf("$$$$$$$$$$$ IMPORT FOUND on line : %d $$$$$$$$$$$", sd.LineNum)
      p.startOfSection("import", "Default")
      p.provider.skipLines(1)
      p.tokenState = 1
    } 
  case 1:
    if sd.Token == ")" && sd.TokenIndex == 0 {
      logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND on line : %d with tokenIndex %d $$$$$$$$$$$", sd.LineNum, sd.TokenIndex)
      p.tokenState = 0
      p.endOfSection()
      return (*CRProducer).scanT1
    } 
  }
  return (*CRProducer).scanT0
}

//----------------------------------------------------------------//
// scanT1
//----------------------------------------------------------------//
func (p *CRProducer) scanT1(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "func" && sd.TokenIndex == 0 {
      p.tokenState = 1
      p.lineNum = sd.LineNum
    } 
  case 1:
    if p.lineNum != sd.LineNum {
      p.tokenState = 0
    } else if sd.Token == "createContainer" {
      logger.Debugf("$$$$$$$$$$$ func createContainer detected with TokenIndex : %d $$$$$$$$$$$$", sd.TokenIndex)
      p.startOfSection("createContainer", "VarDec")
      p.tokenState = 2
    }
  case 2:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      p.lineNum = sd.LineNum
      p.tokenState = 3
    } 
  case 3:
    if sd.Token == "\n" {
      p.tokenState = 0
      p.endOfSection()
      return (*CRProducer).scanT2
    } 
  }
  return (*CRProducer).scanT1
}

//----------------------------------------------------------------//
// scanT2
//----------------------------------------------------------------//
func (p *CRProducer) scanT2(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "func" && sd.TokenIndex == 0 {
      p.tokenState = 1
      p.lineNum = sd.LineNum
    } 
  case 1:
    if p.lineNum != sd.LineNum {
      p.tokenState = 0
    } else if sd.Token == "processPullCommandFlagsInRun" {
      logger.Debugf("$$$$$$$$$$$ func processPullCommandFlagsInRun detected with TokenIndex : %d $$$$$$$$$$$$", sd.TokenIndex)
      p.startOfSection("processPullCommandFlagsInRun", "VarDec")
      p.tokenState = 2
    }
  case 2:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      p.lineNum = sd.LineNum
      p.tokenState = 3
    } 
  case 3:
    if sd.Token == "\n" {
      p.tokenState = 0
      p.endOfSection()
      return (*CRProducer).scanT3
    } 
  }
  return (*CRProducer).scanT2
}

//----------------------------------------------------------------//
// scanT3
//----------------------------------------------------------------//
func (p *CRProducer) scanT3(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "func" && sd.TokenIndex == 0 {
      p.tokenState = 1
      p.lineNum = sd.LineNum
    } 
  case 1:
    if p.lineNum != sd.LineNum {
      p.tokenState = 0
    } else if sd.Token == "generateRootfsOpts" {
      logger.Debugf("$$$$$$$$$$$$ func generateRootfsOpts detected $$$$$$$$$$$$")
      p.startOfSection("generateRootfsOpts", "VarDec", "CopyC")
      p.tokenState = 2
    }
  case 2:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      p.tokenState = 3
    } 
  case 3:
    if sd.Token == "\n" {
      p.tokenState = 0
      p.endOfSection()
      p.startOfSection("generateLogURI", "Default")
      return (*CRProducer).scanT4
    } 
  }
  return (*CRProducer).scanT3
}

//----------------------------------------------------------------//
// scanT4
//----------------------------------------------------------------//
func (p *CRProducer) scanT4(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      p.tokenState = 1
    } 
  case 1:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      p.tokenState = 2
    } 
  case 2:
    if sd.Token == "\n" {
      p.tokenState = 0
      p.endOfSection()
      return (*CRProducer).scanT5
    } 
  }
  return (*CRProducer).scanT4
}

//----------------------------------------------------------------//
// scanT5
//----------------------------------------------------------------//
func (p *CRProducer) scanT5(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "func" && sd.TokenIndex == 0 {
      p.tokenState = 1
      p.lineNum = sd.LineNum
    } 
  case 1:
    if p.lineNum != sd.LineNum {
      p.tokenState = 0
    } else if sd.Token == "withContainerLabels" {
      logger.Debugf("$$$$$$$$$$$$ func withContainerLabels detected $$$$$$$$$$$$")
      p.startOfSection("withContainerLabels", "CopyB")
      p.tokenState = 2
    }
  case 2:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      p.tokenState = 3
    } 
  case 3:
    if sd.Token == "\n" {
      p.tokenState = 0
      p.endOfSection()
      return (*CRProducer).scanT6
    } 
  }
  return (*CRProducer).scanT5
}

//----------------------------------------------------------------//
// scanT6
//----------------------------------------------------------------//
func (p *CRProducer) scanT6(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "func" && sd.TokenIndex == 0 {
      p.tokenState = 1
      p.lineNum = sd.LineNum
    } 
  case 1:
    if p.lineNum != sd.LineNum {
      p.tokenState = 0
    } else if sd.Token == "readKVStringsMapfFromLabel" {
      logger.Debugf("$$$$$$$$$$$$ func readKVStringsMapfFromLabel detected $$$$$$$$$$$$")
      p.startOfSection("readKVStringsMapfFromLabel", "VarDec")
      p.tokenState = 2
    }
  case 2:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      p.tokenState = 3
    } 
  case 3:
    if sd.Token == "\n" {
      p.tokenState = 0
      p.endOfSection()
      return (*CRProducer).scanT7
    } 
  }
  return (*CRProducer).scanT6
}

//----------------------------------------------------------------//
// scanT7
//----------------------------------------------------------------//
func (p *CRProducer) scanT7(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "func" && sd.TokenIndex == 0 {
      p.tokenState = 1
      p.lineNum = sd.LineNum
    } 
  case 1:
    if p.lineNum != sd.LineNum {
      p.tokenState = 0
    } else if sd.Token == "parseKVStringsMapFromLogOpt" {
      logger.Debugf("$$$$$$$$$$$$ func parseKVStringsMapFromLogOpt detected $$$$$$$$$$$$")
      p.startOfSection("parseKVStringsMapFromLogOpt", "VarDec")
      p.tokenState = 2
    }
  case 2:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      p.tokenState = 3
    } 
  case 3:
    if sd.Token == "\n" {
      p.tokenState = 0
      p.endOfSection()
      return (*CRProducer).scanT8
    } 
  }
  return (*CRProducer).scanT7
}

//----------------------------------------------------------------//
// scanT8
//----------------------------------------------------------------//
func (p *CRProducer) scanT8(sd *ScanData) TokenParser_CRP {
  switch p.tokenState {
  case 0:
    if sd.Token == "func" && sd.TokenIndex == 0 {
      p.tokenState = 1
      p.lineNum = sd.LineNum
    } 
  case 1:
    if p.lineNum != sd.LineNum {
      p.tokenState = 0
    } else if sd.Token == "withStop" {
      logger.Debugf("$$$$$$$$$$$$ func withStop detected $$$$$$$$$$$$")
      p.tokenState = 0
      p.startOfSection("withStop", "Default")
      return nil
    }
  }
  return (*CRProducer).scanT8
}


//----------------------------------------------------------------//
// setEditor
//----------------------------------------------------------------//
func (p *CRProducer) setEditor(kind string) error {
  x, err := p.provider.getEditor(kind)
  if err != nil {
    return err
  }
  err = x.Start()
  p.SetNext(x)
  return err
}

//----------------------------------------------------------------//
// startOfSection - TODO => handle errors properly
//----------------------------------------------------------------//
func (p *CRProducer) startOfSection(sectionName string, kinds ...string) {
  logger.Debugf("@@@@@@@@@@@@ %s - section %s start @@@@@@@@@@@@", p.Desc, sectionName)
  p.provider.dd.SetSectionName(sectionName)
  p.sectionName = sectionName
  for _, kind := range kinds {
    logger.Debugf("@@@@@@@@@@@@ %s - setting %s editor in section %s @@@@@@@@@@@@", p.Desc, kind, sectionName)
    err := p.setEditor(kind)
    if err != nil {
      logger.Errorf("%s editor creation failed : %v", kind, err)
      return
    }
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *CRProducer) Run(scanner scanner.Scanner) error {
  p.provider.Start()

  p.lineParser = (*CRProducer).scanL0
  p.tokenParser = (*CRProducer).scanT0

  handler := han.NewScanHandler(p, p.provider.skipLineCount)

  return handler.Run(scanner)
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (p *CRProducer) UseToken(sd *ScanData) {
  if p.tokenParser != nil {
    p.tokenParser = p.tokenParser(p, sd)
  }
}
