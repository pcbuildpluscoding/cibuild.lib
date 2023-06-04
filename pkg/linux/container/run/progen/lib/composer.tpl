package run

import (
	"bufio"
	"io"

	cwt "github.com/pcbuildpluscoding/types/connware"
)

//================================================================//
// PGComposer
//================================================================//
type PGComposer struct {
  Statial
  dealer SnipDealer
  skipLineCount *int
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (c *PGComposer) EndOfFile(...string) {
  c.dealer.writer.Close()
}

//----------------------------------------------------------------//
// Receive
//----------------------------------------------------------------//
func (c *PGComposer) Receive(readCh chan string) error {
  logger.Debugf("%s is receiving ...", c.Desc)
  for !c.Is(cwt.Stopped) {
    switch c.Status() {
    case cwt.Starting:
      c.SetStatus(cwt.Running)
    case cwt.Running:
      select {
      case line, ok := <-readCh:
        if !ok {
          logger.Errorf("%s - input data channel closed before scanning was complete", c.Desc)
          c.SetStatus(cwt.Stopped)
        }
        if line == "EOF" {
          logger.Debugf("!!!! %s got EOF, stopping ...", c.Desc)
          c.SetStatus(cwt.Stopped)
        } else {
          c.dealer.Read(line)
        }
      }
    }
  }
  close(readCh)
  return nil
}

//----------------------------------------------------------------//
// Run
//----------------------------------------------------------------//
func (c *PGComposer) Run(reader io.Reader) ApiRecord {
  err := c.dealer.Start()
  if err != nil {
    return c.WithErr(err)
  }

  scanner := bufio.NewScanner(reader)
  scanner.Split(bufio.ScanLines)

  for scanner.Scan() {
    err = c.dealer.Read(scanner.Text())
    if err != nil {
      logger.Error(err)
    }
  }

  logger.Debugf("!!!!!!!!! done : %v !!!!!!!!!!", err)
  return c.CheckErr(err)
}

//----------------------------------------------------------------//
// String
//----------------------------------------------------------------//
func (c *PGComposer) String() string {
  return c.Desc
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (c *PGComposer) skipLines(skipLineCount int) {
  *c.skipLineCount = skipLineCount
}