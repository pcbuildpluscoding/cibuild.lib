package run

import (
	"errors"
	"fmt"
	"os"
	"strings"

	stx "github.com/pcbuildpluscoding/strucex/std"
)

//================================================================//
// NilBranchErr
//================================================================//
type NilBranchErr struct {
  dbkey string
}

func (e *NilBranchErr) Is(target error) bool {
  _, ok := target.(*NilBranchErr)
  return ok
}

func (e *NilBranchErr) Error() string {
  return fmt.Sprintf("SnipTree branch %s does not exist", e.dbkey)
}

//----------------------------------------------------------------//
// newSnipBranch
//----------------------------------------------------------------//
func newSnipBranch(connex *Trovian, pkgName string, nodeKey string, writer SnipWriter) (*SnipBranch, error) {
  defBranch, err := getBranch(connex, "default", nodeKey)
  if err != nil {
    return nil, err
  }

  logger.Debugf("$$$$$$$$$ got default branch : %v $$$$$$$$$$", *defBranch)

  var nbe NilBranchErr
  otherBranch, err := getBranch(connex, pkgName, nodeKey)
  if err != nil {
    if errors.Is(err, &nbe) {
      return defBranch.update(writer, nil)
    }
    return nil, err
  }

  return defBranch.update(writer, otherBranch)
}

//----------------------------------------------------------------//
// getBranch
//----------------------------------------------------------------//
func getBranch(connex *Trovian, pkgName, nodeKey string) (*SnipBranch, error) {
  dbkey := pkgName + "/SnipTree/" + nodeKey
  if found,_ := connex.HasKey(dbkey); !found {
    return nil, &NilBranchErr{dbkey}
  }

  dataset,_ := stx.NewParameter(nil)
  err := connex.Get(dbkey, dataset)
  if err != nil {
    return nil, err
  }

  branch := SnipBranch{
    connex: connex,
    pkgName: pkgName}
  err = branch.arrange(nodeKey, dataset.ParamList())
  if err != nil {
    return nil, err 
  }
  return &branch, nil
}

//================================================================//
// SnipBranch
//================================================================//
type SnipBranch struct {
  connex *Trovian
  item *SnipItem
  keySet []string
  next *SnipBranch
  this map[string]*SnipItem
  pkgName string
  writer SnipWriter
}

//----------------------------------------------------------------//
// arrange
//----------------------------------------------------------------//
func (b *SnipBranch) arrange(nodeKey string, dataset []Parameter) error {
  b.this = make(map[string]*SnipItem, len(dataset))
  b.keySet = make([]string, len(dataset))
  for i, item := range dataset {
    pitem := item.ParamList()
    if len(pitem) < 3 {
      return fmt.Errorf("Arrange failed - parameter list length is less than required size of 3 : %d", len(pitem))
    }
    name := pitem[0].String()
    dbkey := nodeKey + "/" + name
    b.this[name] = &SnipItem{
        pkgName: b.pkgName,
        dbkey: dbkey,
        indentSize: pitem[1].Int(), 
        leafNode: pitem[2].Bool(),
        token: "snip:" + dbkey}
    b.keySet[i] = name
  }
  return nil
}

//----------------------------------------------------------------//
// newSubBranch
//----------------------------------------------------------------//
func (b *SnipBranch) newSubBranch() (*SnipBranch, error) {
  subkey := b.item.getSubBranchKey()
  return newSnipBranch(b.connex, b.pkgName, subkey, b.writer)
}

//----------------------------------------------------------------//
// update
//----------------------------------------------------------------//
func (b *SnipBranch) update(writer SnipWriter, primary *SnipBranch) (*SnipBranch, error) {
  b.writer = writer
  if primary == nil {
    return b, b.setNext()
  }

  for _, key := range primary.keySet {
    b.this[key] = primary.this[key]
  }
  return b, b.setNext()
}

//----------------------------------------------------------------//
// printBranch
//----------------------------------------------------------------//
func (b *SnipBranch) printBranch() error {
  if !b.item.leafNode {
    return b.printSubBranch()
  }
  err := b.printSnip()
  if err != nil {
    return err
  }
  return b.setNext()
}

//----------------------------------------------------------------//
// PrintSnip
//----------------------------------------------------------------//
func (b *SnipBranch) printSnip() error {
  dbkey := b.item.getDbKey()
  if found,_ := b.connex.HasKey(dbkey); !found {
    return fmt.Errorf("!!! SnipTree element %s is undefined", dbkey)
  } 
  var snipText string
  err := b.connex.Get(dbkey, &snipText)
  if err != nil {
    return err
  }
  logger.Debugf("printing %s snip content ...", b.item.dbkey)
  for _, line := range strings.Split(snipText, "\n") {
    if b.next != nil {
      if b.next.snipItemFound(line) {
        err = b.next.printBranch()
        if err != nil {
          return err
        }
        continue
      }
    }
    b.writer.Print(line)
  }
  if b.next != nil {
    logger.Debugf("$$$$$$ subNode printing is now complete $$$$$$")
    b.next = nil
    b.setNext()
  }
  return nil
}

//----------------------------------------------------------------//
// printSubBranch
//----------------------------------------------------------------//
func (b *SnipBranch) printSubBranch() error {
  var err error
  b.next, err = b.newSubBranch()
  if err != nil {
    return err
  }
  return b.printSnip()
}

//----------------------------------------------------------------//
// setNext
//----------------------------------------------------------------//
func (b *SnipBranch) hasNext() bool {
  return len(b.keySet) > 0
}

//----------------------------------------------------------------//
// setNext
//----------------------------------------------------------------//
func (b *SnipBranch) setNext() error {
  if !b.hasNext() {
    return nil
  }
  itemKey := b.keySet[0]
  b.item = b.this[itemKey]
  b.writer.SetIndent(b.item.indentSize)
  delete(b.this, itemKey)
  b.keySet = b.keySet[1:]
  logger.Debugf("next search token : %s", b.item.token)
  return nil
}

//----------------------------------------------------------------//
// snipItemFound
//----------------------------------------------------------------//
func (b *SnipBranch) snipItemFound(line string) bool {
  return XString(line).XTrim().Contains(b.item.token)
}

//================================================================//
// SnipItem
//================================================================//
type SnipItem struct {
  dbkey string
  pkgName string
  indentSize int
  token string
  leafNode bool
}

//----------------------------------------------------------------//
// getSubBranchKey
//----------------------------------------------------------------//
func (i *SnipItem) getSubBranchKey() string {
  index, remnant := XString(i.dbkey).SplitInTwo("/")
  subindex,_ := index.ToInt()
  return fmt.Sprintf("%d/%s", subindex+1, remnant.String())
}

//----------------------------------------------------------------//
// getDbKey
//----------------------------------------------------------------//
func (i *SnipItem) getDbKey() string {
  return i.pkgName + "/" + i.dbkey
}

//================================================================//
// SnipDealer
//================================================================//
type Void struct{}
type SnipDealer struct {
  Desc string
  connex *Trovian
  root *SnipBranch
  writer SnipWriter
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (d *SnipDealer) Arrange(rw Runware) error {
  logger.Debugf("%s is arranging ...", d.Desc)
  var nodeKey string
  err := d.connex.Get("default/SnipTree/Root", &nodeKey)
  if err != nil {
    return err
  }
  d.root, err = newSnipBranch(d.connex, rw.String("Package"), nodeKey, d.writer)
  logger.Debugf("$$$$$$ got root keyset length : %d $$$$$$", len(d.root.keySet))
  return err
}

//----------------------------------------------------------------//
// Read
//----------------------------------------------------------------//
func (d *SnipDealer) Read(line string) error {
  if d.root.snipItemFound(line) {
    return d.root.printBranch()
  }
  d.writer.Write(line)
  return nil
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (d *SnipDealer) Start() error {
  return nil
}

//================================================================//
// SnipWriter
//================================================================//
type SnipWriter struct {
  indent string
  writer *os.File
}

//----------------------------------------------------------------//
// Close
//----------------------------------------------------------------//
func (w *SnipWriter) Close() error {
  return w.writer.Close()
}

//----------------------------------------------------------------//
// SetIndent
//----------------------------------------------------------------//
func (w *SnipWriter) SetIndent(indentSize int) {
  if indentSize == 0 {
    w.indent = ""
  }
  indentFmt := "%" + fmt.Sprintf("%ds", indentSize)
  w.indent = fmt.Sprintf(indentFmt, " ")
}

//----------------------------------------------------------------//
// Print
//----------------------------------------------------------------//
func (w SnipWriter) Print(lines ...string) {
  for _, line := range lines {
    if line != "" {
      fmt.Fprintln(w.writer, w.indent + line)
    }
  }
}

//----------------------------------------------------------------//
// Write
//----------------------------------------------------------------//
func (w SnipWriter) Write(lines ...string) {
  for _, line := range lines {
    fmt.Fprintln(w.writer, line)
  }
}