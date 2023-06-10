package run

import (
	"bufio"
)

//================================================================//
// ScanReader
//================================================================//
type ScanReader interface {
  Read(string) error
  String() string
}

//================================================================//
// ScanHandler
//================================================================//
type ScanHandler struct {
  Desc string
  readCh chan string
}

//----------------------------------------------------------------//
// Send
//----------------------------------------------------------------//
func (h *ScanHandler) Send(line string) {
  select {
  case <-h.readCh:
    logger.Errorf("%s - input data channel has closed before the end of file reading", h.Desc)
  default:
    h.readCh<- line
  }
}

//----------------------------------------------------------------//
// Run
//----------------------------------------------------------------//
func (h *ScanHandler) Run(scanner *bufio.Scanner) {
  logger.Infof("%s is running ...", h.Desc)

  scanner.Split(bufio.ScanLines)

  for scanner.Scan() {
    h.Send(scanner.Text())
  }
  h.Send("EOF")
}

