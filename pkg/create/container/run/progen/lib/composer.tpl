package run

import (
	"bufio"
	"os"
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
// Run
//----------------------------------------------------------------//
func (c *PGComposer) Run(rw Runware) ApiRecord {
  err := c.dealer.Start()
  if err != nil {
    return c.WithErr(err)
  }

  reader, err := os.Open(rw.String("InputFile"))
  if err != nil {
    return c.WithErr(err, 400)
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