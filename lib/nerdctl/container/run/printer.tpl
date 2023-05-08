package run

import (
	"fmt"

	spb "google.golang.org/protobuf/types/known/structpb"
)

//================================================================//
// VardecPrinter - Container Run Section Printer
//================================================================//
type VardecPrinter struct {
  StdPrinter
}

//----------------------------------------------------------------//
// getVardecSet
//----------------------------------------------------------------//
func (p *VardecPrinter) getVardecSet() ([]string, error) {
  logger.Debugf("!!!!!!!! DataDealer.props, vardecset dbkey : %s, %s, %s !!!!!!!!", p.Desc, p.Dealer.String(), p.Dealer.GetDbKey("vardec-count"))
  vardecCount := 0
  err := p.Dealer.Get("vardec-count", &vardecCount)
  
  if err != nil {
    return nil, fmt.Errorf("%s trovian get vardec-count request failed : %v", p.Desc, err)
  }

  logger.Debugf("variable declarations count : %d", vardecCount)
  
  vardecSet := make([]string, vardecCount)

  err = p.Dealer.BatchGet("vardec/").Use(func(x *spb.Struct) error {
    key := ""
    for i := 0; i < vardecCount; i++ {
      key = p.Dealer.GetDbKey(fmt.Sprintf("vardec/%02d", i))
      if v, found := x.Fields[key]; found {
        vardecSet[i] = v.GetStringValue()
      }
    }
    return nil
  })
  return vardecSet, err
}

//----------------------------------------------------------------//
// getVardecErrTest
//----------------------------------------------------------------//
func (p *VardecPrinter) getVardecErrTest() ([]string, error) {
  lines := []string{}
  err := p.Dealer.Get("vardec-errtest", &lines)

  if err != nil {
    return nil, fmt.Errorf("%s trovian get vardec-errtest request failed : %v", p.Desc, err)
  }

  return lines, err
}

//----------------------------------------------------------------//
// prepare
//----------------------------------------------------------------//
func (p *VardecPrinter) prepare() {
  vardecSet, err := p.getVardecSet()
  if err != nil {
    logger.Error(err)
  }
  logger.Debugf("$$$$$$$$$$ got variable declarations set : %v $$$$$$$$$$$$", vardecSet)
  p.Writer.SetProperty("vardecSet", vardecSet)
  vardecErrTest, err := p.getVardecErrTest()
  if err != nil {
    logger.Error(err)
  }
  logger.Debugf("$$$$$$$$$$ got vardec error test lines : %v $$$$$$$$$$$$", vardecErrTest)
  p.Writer.SetProperty("vardecErrTest", vardecErrTest)

}

//----------------------------------------------------------------//
// Print
//----------------------------------------------------------------//
func (p *VardecPrinter) Print() error {
  p.prepare()
  return p.StdPrinter.Print()
}
