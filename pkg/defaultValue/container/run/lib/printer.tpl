package run

import (
  "fmt"
  "regexp"
  "strings"

  spb "google.golang.org/protobuf/types/known/structpb"
)

//================================================================//
// DVContentPrinter
//================================================================//
type DVContentPrinter struct {
  Desc string
  dd *DataDealer
  regex map[string]*regexp.Regexp
  writer LineWriter
}

//----------------------------------------------------------------//
// getProps
// returned values - varType, defValue, isPackageReferenceValue
//----------------------------------------------------------------//
func getProps(x []*spb.Value) (string, string, bool, error) {
  if len(x) < 3 {
    return "", "", false, fmt.Errorf("importRef record length is less than 3")
  }
  return x[0].GetStringValue(), 
    x[1].GetStringValue(), 
    x[2].GetBoolValue(), nil
}

//----------------------------------------------------------------//
// rewriteSliceValue
//----------------------------------------------------------------//
func rewriteSliceValue(value string) (string, error) {
  parts := strings.SplitN(value, "{", 2)
  if len(parts) == 1 {
    return "", fmt.Errorf("unexpected slice value format : %s", value)
  }
  if ! strings.Contains(parts[1], "}") {
    return "", fmt.Errorf("unexpected slice value format : %s", value)
  }
  extract := strings.Replace(parts[1], "}", "", 1)
  return fmt.Sprintf("[]interface{}{%s}", extract), nil
}

//----------------------------------------------------------------//
// Print
//----------------------------------------------------------------//
func (p *DVContentPrinter) Print() error {
  logger.Debugf("@@@@@@@@@@@ printing section : %s @@@@@@@@@@", p.dd.SectionName)
  content := []interface{}{}
  p.dd.SetSectionName("content")
  dbkey := p.dd.GetDbKey("/")
  p.dd.BatchGet("").Use(func(s *spb.Struct) error {
    for varName, svalue := range s.Fields {
      varName = strings.Replace(varName, dbkey, "", 1)
      varType, value, _, err := getProps(svalue.GetListValue().Values)
      if err != nil {
        logger.Error(err)
        return nil
      }
      switch varType {
      case "String":
        if value == `""` {
          continue
        }
        content = append(content, fmt.Sprintf(`    "%s": %v,`, varName, value))
      case "Bool":
        if value != "false" {
          content = append(content, fmt.Sprintf(`    "%s": %s,`, varName, value))
        }
      default:
        switch {
        case p.regex["SliceType"].MatchString(varType):
          if value == "nil" {
            continue
          }
          value, err = rewriteSliceValue(value)
          if err != nil {
            logger.Error(err)
            continue
          }
          content = append(content, fmt.Sprintf(`    "%s": %s,`, varName, value))
        case p.regex["NumberType"].MatchString(varType):
          content = append(content, fmt.Sprintf(`    "%s": %s,`, varName, value))
        default:
          logger.Debugf("$$$$$$ unhandled vartype, value : %s, %s $$$$$", varType, value)
          content = append(content, fmt.Sprintf(`    "%s": %s,`, varName, value))
        }
      }
    }
    return nil
  })
  p.writer.Write(content...)
  return nil
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *DVContentPrinter) SetProperty(propName string, value interface{}) error {
  switch propName {
  case "SectionName":
    if sectionName, ok := value.(string); ok {
      p.dd.Desc = p.Desc
      p.dd.SetSectionName(sectionName)
    }
  }
  return nil
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *DVContentPrinter) Start() error {
  if p.regex == nil {
    p.regex = map[string]*regexp.Regexp{}
    p.regex["SliceType"], _ = regexp.Compile(`Array|Slice`)
    p.regex["NumberType"], _ = regexp.Compile(`Uint|Int|Float`) 
  }
  return nil
}

//================================================================//
// DVImportPrinter
//================================================================//
type DVImportPrinter struct {
  Desc string
  dd *DataDealer
  writer LineWriter
}

//----------------------------------------------------------------//
// Print
//----------------------------------------------------------------//
func (p *DVImportPrinter) Print() error {
  logger.Debugf("@@@@@@@@@@@ printing section : %s @@@@@@@@@@", p.dd.SectionName)
  x := []interface{}{}
  p.dd.SetSectionName("required.imports")
  err := p.dd.Get("", &x)
  if err != nil {
    return err
  }
  logger.Debugf("dbkey, result : %s, %v", p.dd.GetDbKey(), x)
  p.writer.Write(x...)
  return nil
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *DVImportPrinter) SetProperty(propName string, value interface{}) error {
  switch propName {
  case "SectionName":
    if sectionName, ok := value.(string); ok {
      p.dd.Desc = p.Desc
      p.dd.SetSectionName(sectionName)
    }
  }
  return nil
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *DVImportPrinter) Start() error {
  return nil
}