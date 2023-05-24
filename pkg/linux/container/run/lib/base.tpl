package run

import (
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/pcbuildpluscoding/apibase/loggar"
	elm "github.com/pcbuildpluscoding/genware/lib/element"
	fs "github.com/pcbuildpluscoding/genware/lib/filesystem"
	han "github.com/pcbuildpluscoding/genware/lib/handler"
	tdb "github.com/pcbuildpluscoding/trovedb/std"
	rdt "github.com/pcbuildpluscoding/types/apirecord"
	rwt "github.com/pcbuildpluscoding/types/runware"
	"github.com/sirupsen/logrus"
)

type ApiRecord = rdt.ApiRecord
type Blacklist = elm.Blacklist
type Component = elm.Component
type DataDealer = elm.DataDealer
type ScanData = han.ScanData
type LineWriter = elm.LineWriter
type Printer = elm.Printer
type Runware = rwt.Runware
type StdPrinter = elm.StdPrinter
type TextConsumer = han.TextConsumer
type Trovian = tdb.Trovian
type VarDecErrTest = elm.VarDecErrTest
type XString = fs.XString

var logger = loggar.Get()

// -------------------------------------------------------------- //
// SetLogger
// ---------------------------------------------------------------//
func SetLogger(super *logrus.Logger) {
  logger = super
}

//----------------------------------------------------------------//
// NewCRProducer
//----------------------------------------------------------------//
func NewCRProducer(connex *Trovian, spec Runware) (*CRProducer, error) {
  logger.Debugf("$$$$$$$$$$$ creating CRProducer with spec : %v $$$$$$$$$$$", spec.AsMap())
  desc := "CRProducer-" + time.Now().Format("150405.000000")
  count := 0
  provider, err := NewTCProvider(connex, spec, &count)
  if err != nil {
    return nil, err
  }
  rw := spec.SubNode("Arrangement")
  if rw.String("BucketName") == "" {
    return nil, fmt.Errorf("%s - required jobspec bucketName is undefined", desc)
  }
  provider.dd.ToggleBucketName(rw.String("BucketName"))
  err = provider.Arrange(rw)
  if err != nil {
    return nil, err
  }
  dealer := NewSectionDealer(&count)
  err = dealer.Arrange(provider.dd, rw)
  if err != nil {
    return nil, err
  }
  provider.dd.ToggleBucketName()
  return &CRProducer{
    Component: Component{Desc: desc},
    dealer: dealer,
    provider: provider,
    skipLineCount: &count,
  }, err
}

//----------------------------------------------------------------//
// NewCRComposer
//----------------------------------------------------------------//
func NewCRComposer(connex *Trovian, spec Runware, writer LineWriter) (*CRComposer, error) {
  logger.Debugf("$$$$$$$$$$$ creating CRComposer with spec : %v $$$$$$$$$$$", spec.AsMap())
  count := 0
  desc := "CRComposer-" + time.Now().Format("150405.000000")
  provider, err := NewPrintProvider(connex, spec, writer)
  if err != nil {
    return nil, err
  }
  err = provider.Arrange(spec)
  return &CRComposer{
    Component: Component{Desc: desc},
    skipLineCount: &count,
    provider: provider,
    writer: writer,
  }, err
}

//----------------------------------------------------------------//
// NewPrintProvider
//----------------------------------------------------------------//
func NewPrintProvider(connex *Trovian, spec Runware, writer LineWriter) (PrintProvider, error) {
  desc := "PrintProvider-" + time.Now().Format("150405.000000")
  dd, err := elm.NewDataDealer(desc, connex, spec)
  return PrintProvider{
    dd: &dd,
    cache: map[string]Printer{},
    spec: spec,
    writer: writer,
  }, err
}

//----------------------------------------------------------------//
// NewTCProvider
//----------------------------------------------------------------//
func NewTCProvider(connex *Trovian, spec Runware, count *int) (TCProvider, error) {
  desc := "TCProvider-" + time.Now().Format("150405.000000")
  dd, err := elm.NewDataDealer(desc, connex, spec)
  return TCProvider{
    dd: &dd,
    cache: map[string]TextParser{},
    skipLineCount: count,
    spec: spec,
  }, err
}

//----------------------------------------------------------------//
// NewLineCopier
//----------------------------------------------------------------//
func NewLineCopier(dd *DataDealer, count *int, darg ...string) LineCopier {
  desc := "LineParserA-" + time.Now().Format("150405.000000")
  if darg != nil {
    desc = darg[0]
  }
  return LineCopier{
    Desc: desc,
    dd: dd,
    skipLineCount: count,
  }
}

//----------------------------------------------------------------//
// NewLineParserA
//----------------------------------------------------------------//
func NewLineParserA(dd *DataDealer, count *int, spec Runware) (*LineParserA, error) {
  desc := "LineParserA-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  blacklist, err := elm.NewBlacklist(spec.SubNode("Arrangement"))
  if err != nil {
    return nil, err
  }
  return &LineParserA{
    LineCopier: NewLineCopier(dd, count, desc),
    blacklist: blacklist,
    buffer: []interface{}{},
  }, nil
}

//----------------------------------------------------------------//
// NewLineParserB
//----------------------------------------------------------------//
func NewLineParserB(dd *DataDealer, count *int) (*LineParserB, error) {
  desc := "LineParserB-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &LineParserB{
    LineCopier: NewLineCopier(dd, count, desc),
  }, nil
}

//----------------------------------------------------------------//
// NewSectionDealer
//----------------------------------------------------------------//
func NewSectionDealer(count *int) SectionDealer {
  return SectionDealer{
    Desc: "SectionDealer-" + time.Now().Format("150405.000000"),
    skipLineCount: count,
  }
}

//================================================================//
// VarDec
//================================================================//
type VarDec struct {
  varName string
  flagName string
  varType string
  equalToken string
  indentFactor int
  indentSize int
  inlineErr bool
  isSlice *regexp.Regexp
}

//----------------------------------------------------------------//
// DecIndent
//----------------------------------------------------------------//
func (d *VarDec) DecIndent() {
  d.indentFactor -= 1
}

//----------------------------------------------------------------//
// getIndent
//----------------------------------------------------------------//
func (d VarDec) getIndent() string {
  indentFmt := "%" + fmt.Sprintf("%ds", d.indentFactor * d.indentSize)
  return fmt.Sprintf(indentFmt, " ")
}

//----------------------------------------------------------------//
// GetIndentFactor
//----------------------------------------------------------------//
func (d *VarDec) GetIndentFactor() int {
  return d.indentFactor
}

//----------------------------------------------------------------//
// GetParamSetter
//----------------------------------------------------------------//
func (d VarDec) GetParamSetter() string {
  indent := d.getIndent()
  return fmt.Sprintf("%sp := cspec.Parameter(\"%s\")", indent, d.flagName)
}

//----------------------------------------------------------------//
// GetParamValue
//----------------------------------------------------------------//
func (d VarDec) GetParamValue() string {
  indent := d.getIndent()
  if d.inlineErr {
    return fmt.Sprintf("%s%s %s p.%s(); p.Err() != nil {", indent, d.varName, d.equalToken, d.varType)
  }
  return fmt.Sprintf("%s%s %s p.%s()", indent, d.varName, d.equalToken, d.varType)
}

//----------------------------------------------------------------//
// GetVarDec
//----------------------------------------------------------------//
func (d VarDec) GetVarDec() string {
  goVarType := strings.ToLower(d.varType)
  switch d.varType {
  case "StringList":
    goVarType = "[]string"
  case "ParamList":
    goVarType = "[]Parameter"
  }
  indent := d.getIndent()
  return fmt.Sprintf("%svar %s %s", indent, d.varName, goVarType)
}

//----------------------------------------------------------------//
// GetVarSetter
//----------------------------------------------------------------//
func (d VarDec) GetVarSetter() string {
  indent := d.getIndent()
  return fmt.Sprintf("%s%s %s cspec.%s(\"%s\")", indent, d.varName, d.equalToken, d.varType, d.flagName)
}

//----------------------------------------------------------------//
// IndentLine
//----------------------------------------------------------------//
func (d VarDec) IndentLine(text string) string {
  indent := d.getIndent()
  return fmt.Sprintf("%s%s", indent, text)
}

//----------------------------------------------------------------//
// IncIndent
//----------------------------------------------------------------//
func (d *VarDec) IncIndent() {
  d.indentFactor += 1
}

//----------------------------------------------------------------//
// ParseGetter
//----------------------------------------------------------------//
func (d *VarDec) ParseGetter(line string) *VarDec {
  varText, remnant := XString(line).SplitInTwo(", ")
  _, equalToken, remnantA := remnant.SplitInThree(" ")
  varType, flagName := remnantA.SplitNKeepOne("Flags().Get",2,1).SplitInTwo(`("`)
  inlineErr := flagName.Contains("err != nil")
  if inlineErr {
    flagName, _ = flagName.SplitInTwo(`")`)
  } else {
    flagName.Replace(`")`, "", 1)
  }
  var varName string
  if varText.Contains("if") {
    varName = varText.SplitNKeepOne(" ",2,1).Trim()
  } else {
    varName = varText.Trim()
  }
  d.parseVarType(varType)
  d.varName = varName
  d.flagName = flagName.String()
  d.equalToken = equalToken.String()
  d.inlineErr = inlineErr
  return d
}

//----------------------------------------------------------------//
// ResetIndent
//----------------------------------------------------------------//
func (d *VarDec) ResetIndent() {
  d.indentFactor = 1
}

//----------------------------------------------------------------//
// parseVarType
//----------------------------------------------------------------//
func (d *VarDec) parseVarType(varType XString) {
  d.varType = varType.String()
  if d.isSlice.MatchString(varType.String()) {
    if varType.Contains("String") {
      d.varType = "StringList"
    } else {
      d.varType = "ParamList"
    }
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (d *VarDec) Start() error {
  var err error
  d.isSlice, err = regexp.Compile("Slice|Array")
  return err
}