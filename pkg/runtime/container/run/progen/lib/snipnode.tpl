package run

import (
	"fmt"
	"os"
	"strings"

	stx "github.com/pcbuildpluscoding/strucex/std"
)

//================================================================//
// SnipItem
//================================================================//
type SnipItem struct {
  key string
  indentSize int
  token string
  leafNode bool
  remnant []string
}

//----------------------------------------------------------------//
// hasMore
//----------------------------------------------------------------//
func (i *SnipItem) hasMore() bool {
  return len(i.remnant) > 0
}

//================================================================//
// AddSubNodeReq
//================================================================//
type AddSubNodeReq struct {
  nodeKey string
  respCh chan []Parameter
}

//================================================================//
// SnipNode
//================================================================//
type SnipNode struct {
  connex *Trovian
  dbPrefix string
  item *SnipItem
  nodeKey string
  keySet []Parameter
  writer SnipWriter
  next *SnipNode
}

//----------------------------------------------------------------//
// newSubNode
//----------------------------------------------------------------//
func (n *SnipNode) newSubNode() (*SnipNode, error) {
  dbkey := n.dbPrefix + "/SnipTree"
  if found,_ := n.connex.HasKey(dbkey); !found {
    return nil, fmt.Errorf("SnipNode runware parameter |%s| is undefined", dbkey)
  }
  rw, _ := stx.NewRunware(nil)
  err := n.connex.Get(dbkey, rw)
  if err != nil {
    return nil, err
  }

  if !rw.HasKeys(n.item.key) {
    return nil, fmt.Errorf("%s subNode key does not exist in trovedb", n.item.key)
  }

  subNode := &SnipNode{
    connex: n.connex,
    dbPrefix: n.dbPrefix,
    nodeKey: n.item.key,
    keySet: rw.ParamList(n.item.key),
    writer: n.writer,
  }
  return subNode, subNode.setNext()
}

//----------------------------------------------------------------//
// getParams
//----------------------------------------------------------------//
func (n *SnipNode) getParams() []Parameter {
  if len(n.keySet) > 0 {
    return n.keySet[0].ParamList()
  }
  return []Parameter{}
}

//----------------------------------------------------------------//
// getNextItem
//----------------------------------------------------------------//
func (n *SnipNode) getNextItem() (*SnipItem, error) {
  if !n.hasNext() {
    return nil, fmt.Errorf("SnipItem set is empty")
  }
  paramSet := n.getParams()
  if len(paramSet) < 3 {
    return nil, fmt.Errorf("required SnipItem parameter set length = 3, got %d instead", len(paramSet))
  }
  return &SnipItem{
    key: paramSet[0].String(),
    indentSize: paramSet[1].Int(),
    token: fmt.Sprintf("snip:%s",paramSet[0].String()),
    leafNode: paramSet[2].Bool(),
  }, nil
}

//----------------------------------------------------------------//
// hasNext
//----------------------------------------------------------------//
func (n *SnipNode) hasNext() bool {
  return len(n.keySet) > 0
}

//----------------------------------------------------------------//
// printNode
//----------------------------------------------------------------//
func (n *SnipNode) printNode() error {
  if !n.item.leafNode {
    return n.printSubNode()
  }
  err := n.printSnip()
  if err != nil {
    return err
  }
  return n.setNext()
}

//----------------------------------------------------------------//
// PrintSubNode
//----------------------------------------------------------------//
func (n *SnipNode) printSubNode() error {
  var err error
  n.next, err = n.newSubNode()
  if err != nil {
    return err
  }
  return n.printSnip()
}

//----------------------------------------------------------------//
// PrintSnip
//----------------------------------------------------------------//
func (n *SnipNode) printSnip() error {
  dbkey := fmt.Sprintf("%s/%s", n.dbPrefix, n.item.key)
  if found,_ := n.connex.HasKey(dbkey); !found {
    return fmt.Errorf("!!! snipTree element %s is undefined", dbkey)
  } 
  var snipText string
  err := n.connex.Get(dbkey, &snipText)
  if err != nil {
    return err
  }
  logger.Debugf("printing %s snip content ...", n.item.key)
  for _, line := range strings.Split(snipText, "\n") {
    if n.next != nil {
      if n.next.snipItemFound(line) {
        err = n.next.printNode()
        if err != nil {
          return err
        }
        continue
      }
    }
    n.writer.Print(line)
  }
  if n.next != nil {
    logger.Debugf("$$$$$$ subNode printing is now complete $$$$$$")
    n.next = nil
    n.setNext()
  }
  return nil
}

//----------------------------------------------------------------//
// setNext
//----------------------------------------------------------------//
func (n *SnipNode) setNext() error {
  var err error
  n.item, err = n.getNextItem()
  if err != nil {
    return err
  }
  n.writer.SetIndent(n.item.indentSize)
  if len(n.keySet) > 1 {
    n.keySet = n.keySet[1:]
  }
  logger.Debugf("next search token : %s", n.item.token)
  return nil
}

//----------------------------------------------------------------//
// snipItemFound
//----------------------------------------------------------------//
func (n *SnipNode) snipItemFound(line string) bool {
  return XString(line).XTrim().Contains(n.item.token)
}

//================================================================//
// SnipDealer
//================================================================//
type Void struct{}
type SnipDealer struct {
  Desc string
  connex *Trovian
  rootNode *SnipNode
  writer SnipWriter
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (d *SnipDealer) Arrange(spec Runware) error {
  logger.Debugf("%s is arranging ...", d.Desc)
  if !spec.HasKeys("DbPrefix","OutputFile") {
    return fmt.Errorf("%s - one or more required parameters are undefined", d.Desc)
  }

  dbPrefix := spec.String("DbPrefix")
  var err error
  d.writer, err = NewSnipWriter(d.connex, spec.String("OutputFile"))
  if err != nil {
    logger.Error(err)
    return err
  }
  d.rootNode, err = d.newRootNode(dbPrefix)
  logger.Debugf("$$$$$$ got root keyset length : %d $$$$$$", len(d.rootNode.keySet))
  return err
}

//----------------------------------------------------------------//
// newRootNode
//----------------------------------------------------------------//
func (d *SnipDealer) newRootNode(dbPrefix string) (*SnipNode, error) {
  dbkey := dbPrefix + "/SnipTree"
  if found,_ := d.connex.HasKey(dbkey); !found {
    return nil, fmt.Errorf("%s - SnipNode runware parameter |%s| is undefined", d.Desc, dbkey)
  }
  rw,_ := stx.NewRunware(nil)
  err := d.connex.Get(dbkey, rw)
  if err != nil {
    return nil, err
  }

  if !rw.HasKeys("Root") {
    return nil, fmt.Errorf("Root node key does not exist in snip spec")
  }

  nodeKey := rw.String("Root")
  if !rw.HasKeys(nodeKey) {
    return nil, fmt.Errorf("node key %s does not exist in snip spec", nodeKey)
  }
  
  return &SnipNode{
    connex: d.connex,
    dbPrefix: dbPrefix,
    nodeKey: nodeKey,
    keySet: rw.ParamList(nodeKey),
    writer: d.writer,
  }, nil
}

//----------------------------------------------------------------//
// Read
//----------------------------------------------------------------//
func (d *SnipDealer) Read(line string) error {
  if d.rootNode.snipItemFound(line) {
    return d.rootNode.printNode()
  }
  d.writer.Write(line)
  return nil
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (d *SnipDealer) Start() error {
  return d.rootNode.setNext()
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