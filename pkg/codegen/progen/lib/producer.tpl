package progen

import (
	"fmt"
	"strings"
	"text/scanner"

	han "github.com/pcbuildpluscoding/genware/lib/handler"
	stx "github.com/pcbuildpluscoding/strucex/std"
	rwt "github.com/pcbuildpluscoding/types/runware"
)

//================================================================//
// ContentBlock
//================================================================//
type Void struct{}
type ContentBlock struct {
  Desc string
  dd *DataDealer
  markup Runware
  currentSet []string
  blockName string
  level int
  tagCount int
}

//----------------------------------------------------------------//
// addMarkupBlock
//----------------------------------------------------------------//
func (b *ContentBlock) addMarkupBlock(xtoken XString, isNested bool) {
  blockName := xtoken.Replace("// start:","",1).String()
  if isNested {
  // append the nested blockName to the current level markupSet
    b.currentSet = append(b.currentSet, blockName)
    // save the current markupSet in the store using the current blockName key
    b.markup.Set(b.blockName, b.currentSet)
    // increment the nesting level
    b.level += 1
  }
  // create a new empty markupSet for the new level
  b.currentSet = []string{}
  // save the new empty markupSet
  b.markup.Set(blockName, b.currentSet)
  // save the new blockName incrementing the tagCount
  b.blockName = blockName
  b.tagCount += 1
}

//----------------------------------------------------------------//
// putContent
//----------------------------------------------------------------//
func (b *ContentBlock) putContent(subBlockName string, contentSet *[]interface{}, subDataset []stx.Parameter) {
  if subDataset == nil {
    var dataset stx.ValueA1
    err := b.dd.Get(subBlockName, &dataset)
    if err != nil {
      logger.Errorf("%s - failed to fetch %s source code content : %v", b.Desc, subBlockName, err)
      return
    }
    subDataset = dataset.ParamList()
  }

  var schema stx.ValueA1
  err := b.dd.GetWithArgs("schema", []string{subBlockName}, &schema)
  if err != nil {
    logger.Errorf("%s - failed to fetch %s schema metadata : %v", b.Desc, subBlockName, err)
    return
  }

  expandedSet := make([][]interface{}, len(subDataset))
  for i, contentItem := range subDataset {
    expandedSet[i] = b.markup.List(subBlockName).AsSlice()
    for _, markupKey := range schema.StringList() {
      if !contentItem.SubNode().HasKeys(markupKey) {
        // logger.Debugf("$$$$$ %s is NOT found in %s markupSet $$$$$", markupKey, subBlockName)
        for j := range expandedSet[i] {
          if expandedSet[i][j] == markupKey {
            x,_ := expandedSet[i][j].(string)
            expandedSet[i][j] = strings.Replace(x, markupKey,"",1)
          }
        }
        continue
      }
      content := contentItem.SubNode().Parameter(markupKey)
      switch {
      case XString(markupKey).Contains(".level"):
        for j := range expandedSet[i] {
          if expandedSet[i][j] == markupKey {
            subcontentSet := []interface{}{}
            b.putContent(markupKey, &subcontentSet, content.ParamList())
            expandedSet[i][j] = subcontentSet
          }
        }
      default:
        markupTag := "// " + markupKey
        // logger.Debugf("$$$$$$$$$ next markup key : %s", markupKey)
        for j := range expandedSet[i] {
          markupText,_ := expandedSet[i][j].(string)
          if strings.Contains(markupText, markupTag) {
            switch contentItem.Kind() {
            case rwt.Structpb_Struct:
              switch content.Kind() {
              case rwt.Structpb_String:
                expandedSet[i][j] = strings.Replace(markupText, markupTag, content.String(), 1)
              case rwt.Structpb_List:
                indent := strings.Replace(markupText, markupTag, "", 1)
                expandedSet[i][j] = append([]string{indent}, content.StringList()...)
              default:
                logger.Errorf("%s - structpb.String|ListValue expected, got %s for key |%s|", b.Desc, markupKey, content.Kind().String())
              }
            default:
              logger.Errorf("%s - structpb.Struct is required, got %s for key |%s|", b.Desc, contentItem.Kind().String())
            }
          }
        }
      }
    }
  }
  for _, subset := range expandedSet {
    *contentSet = append(*contentSet, subset...)
  }
}

//----------------------------------------------------------------//
// AddBlockMarkup
//----------------------------------------------------------------//
func (b *ContentBlock) addMarkupLine(line string) {
  b.currentSet = append(b.currentSet, line)
}

//----------------------------------------------------------------//
// endOfMarkupDetected
//----------------------------------------------------------------//
func (b *ContentBlock) endOfMarkupDetected() bool {
  return b.tagCount == 0
}

//----------------------------------------------------------------//
// endOfMarkupBlock
//----------------------------------------------------------------//
func (b *ContentBlock) endOfMarkupBlock() {
  // store the currentSet by the current blockName
  b.markup.Set(b.blockName, b.currentSet)
  if b.level > 0 {
    // handle nested endOfBlock condition
    b.level -= 1
    xblockName := XString(b.blockName)
    rootName := xblockName.SplitNKeepOne(".",2,0).String()
    if b.level == 0 {
      b.blockName = rootName
    } else {
      b.blockName = fmt.Sprintf("%s.level%02d", rootName, b.level)
    }
    b.currentSet = b.markup.StringList(b.blockName)
  }
  b.tagCount -= 1
}

//================================================================//
// PGProducer - ProGenProducer
//================================================================//
type LineParser_PGP func(*PGProducer, string) LineParser_PGP
type TokenParser_PGP func(*PGProducer, *ScanData) TokenParser_PGP
type PGProducer struct {
  Component
  block *ContentBlock
  lineParser LineParser_PGP
  lineState int
  skipLineCount *int
  tokenParser TokenParser_PGP
  tokenState int
  level int
  writer LineWriter
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *PGProducer) EditLine(line *string, lineNum int) {
  if p.lineParser != nil {
    p.lineParser = p.lineParser(p, *line)
  }
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (p *PGProducer) EndOfFile(lines ...string) {
  if lines != nil && lines[0] != "\n" {
    p.writer.Write(lines[0])
  }
}

//----------------------------------------------------------------//
// EndOfSection
//----------------------------------------------------------------//
func (p *PGProducer) EndOfSection(line ...string) {}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (p *PGProducer) PutLine(line string) {
  if *p.skipLineCount == 0 {
    p.writer.Write(line)
  }
}

//----------------------------------------------------------------//
// removeDelegate - TODO => handle errors properly
//----------------------------------------------------------------//
func (p *PGProducer) removeDelegate() {
  p.EndOfSection()
  p.RemoveNext()
}

//----------------------------------------------------------------//
// scanL0
// - while inside a markup block line printing is disabled or skipped
// - until the end-of-block is detected all markup is stored in a cache
// - at end-of-block the entire markup block is rendered and printed
//----------------------------------------------------------------//
func (p *PGProducer) scanL0(line string) LineParser_PGP {
  switch p.lineState {
  case 1:
    // end of the start tag line
    p.lineState = 2
    p.skipLines(1)
  case 2:
    p.skipLines(1)
    p.block.addMarkupLine(line)
  case 3:
    // nested subBlock start detected
    p.skipLines(1)
    p.lineState = 2
  case 4:
    // subBlock end detected
    p.skipLines(1)
    // test markup section end. that's means the end of block level 0
    if p.block.endOfMarkupDetected() {
      contentSet := []interface{}{}
      p.block.putContent(p.block.blockName, &contentSet, nil)
      p.writer.Write(contentSet...)
      // reset the state
      p.tokenState = 0
      p.lineState = 0
    } else {
      p.lineState = 2
    }
  }
  return (*PGProducer).scanL0
}

//----------------------------------------------------------------//
// scanT0
//----------------------------------------------------------------//
func (p *PGProducer) scanT0(sd *ScanData) TokenParser_PGP {
  xtoken := XString(sd.Token)
  switch p.tokenState {
  case 0:
    if xtoken.HasPrefix("// start:") {
      p.block.addMarkupBlock(xtoken, false)
      p.lineState = 1
      p.tokenState = 1
    }
  case 1:
    if xtoken.HasPrefix("// stop:") {
      p.block.endOfMarkupBlock()
      p.lineState = 4
    } else if xtoken.HasPrefix("// start:") {
      // logger.Debugf("@@@@@@@ nested block start detected : |%s| lineState : |%d| @@@@@@@", sd.Token, p.lineState)
      p.block.addMarkupBlock(xtoken, true)
      p.lineState = 3
    }
  }
  return (*PGProducer).scanT0
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *PGProducer) Run(scanner scanner.Scanner) error {
  p.lineParser = (*PGProducer).scanL0
  p.tokenParser = (*PGProducer).scanT0

  handler := han.NewScanHandler(p, p.skipLineCount)

  return handler.Run(scanner)
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *PGProducer) Start() error {
  return p.block.dd.Start()
}

//----------------------------------------------------------------//
// String
//----------------------------------------------------------------//
func (p *PGProducer) String() string {
  return p.Desc
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (p *PGProducer) skipLines(skipLineCount int) {
  *p.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (p *PGProducer) UseToken(sd *ScanData) {
  if p.tokenParser != nil {
    p.tokenParser = p.tokenParser(p, sd)
  }
}