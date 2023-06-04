package run

import (
	"fmt"
	"regexp"

	stx "github.com/pcbuildpluscoding/strucex/std"
)

//================================================================//
// Sectional
//================================================================//
type Sectional struct {
  name string
  starting *regexp.Regexp
  ending *regexp.Regexp
  endTimes int
  parserKind []string
  printStart bool
  printEnd bool
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (s Sectional) SectionEnd(line string) bool {
  if s.ending != nil {
    return s.ending.MatchString(line)
  }
  return false
}

//----------------------------------------------------------------//
// SectionStart
//----------------------------------------------------------------//
func (s Sectional) SectionStart(line string) bool {
  return s.starting.MatchString(line)
}

//================================================================//
// SectionDealer
//================================================================//
type SectionDealer struct {
  Desc string
  section []Sectional
  skipLineCount *int
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (d *SectionDealer) Arrange(dd *DataDealer, spec Runware) error {
  logger.Debugf("%s is arranging ...", d.Desc)
  rw,_ := stx.NewRunware(nil)
  dbkey := spec.String("SectionDealer")
  if dbkey == "" {
    return fmt.Errorf("%s - required Arrangement.SectionDealer parameter is undefined", d.Desc)
  }
  err := dd.GetWithKey(dbkey, rw)
  if err != nil {
    return err
  }
  logger.Debugf("%s got jobspec : %v", d.Desc, rw.AsMap())
  d.section = make([]Sectional, len(rw.StringList("Sections")))
  for i, section := range rw.StringList("Sections") {
    subSection := rw.SubNode(section)
    x := Sectional{name: section}
    x.parserKind = subSection.StringList("Workers")
    params := subSection.ParamList("Starting")
    if len(params) < 2 {
      return fmt.Errorf("%s bad arrangement - %s starting parameter list length is < required length of 2", d.Desc, section)
    }
    pattern := params[0].String()
    x.starting, err = regexp.Compile(pattern)
    if err != nil {
      return err
    }
    x.printStart = params[1].Bool()
    if !subSection.HasKeys("Ending") {
      d.section[i] = x
      logger.Debugf("%s got Sectional instance : %v", d.Desc, x)  
      continue
    }
    params = subSection.ParamList("Ending")
    if len(params) < 3 {
      return fmt.Errorf("%s bad arrangement - %s starting parameter list length is < required length of 2", d.Desc, section)
    }
    pattern = params[0].String()
    if pattern != "EOF" {
      x.ending, err = regexp.Compile(pattern)
      if err != nil {
        return err
      }
    }
    x.endTimes = params[1].Int()
    if x.endTimes < 1 {
      return fmt.Errorf("%s bad arrangement - %s endTimes parameter must be >= 1", d.Desc, section)
    }
    x.printEnd = params[2].Bool()
    d.section[i] = x
    logger.Debugf("%s got Sectional instance : %v", d.Desc, x)  
  }
  return nil
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (d *SectionDealer) SectionEnd(line string) bool {
  if !d.hasNext() {
    return false
  }
  found := d.section[0].SectionEnd(line)
  if found {
    if d.section[0].endTimes == 1 {
      logger.Debugf("%s printEnd : %v", d.section[0].name, d.section[0].printEnd)
      if !d.section[0].printEnd {
        *d.skipLineCount = 1
      }
    } else {
      found = false
      d.section[0].endTimes -= 1
    }
  }
  return found
}

//----------------------------------------------------------------//
// SectionStart
//----------------------------------------------------------------//
func (d *SectionDealer) SectionStart(line string) bool {
  if !d.hasNext() {
    return false
  }
  found := d.section[0].SectionStart(line)
  if found {
    logger.Debugf("%s printStart : %v", d.section[0].name, d.section[0].printStart)
    if !d.section[0].printStart {
      *d.skipLineCount = 1
    }
  }
  return found
}

//----------------------------------------------------------------//
// getSectionProps
//----------------------------------------------------------------//
func (d *SectionDealer) getSectionProps() (string, []string) {
  if !d.hasNext() {
    return "error", []string{"error"}
  }
  return d.section[0].name, d.section[0].parserKind
}

//----------------------------------------------------------------//
// hasNext
//----------------------------------------------------------------//
func (d *SectionDealer) hasNext() bool {
  return len(d.section) > 0
}

//----------------------------------------------------------------//
// setNext
//----------------------------------------------------------------//
func (d *SectionDealer) setNext() {
  if len(d.section) > 1 {
    d.section = d.section[1:]
  } else {
    d.section = nil
  }
}