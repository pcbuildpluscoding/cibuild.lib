// The MIT License
//
// Copyright (c) 2023 Peter A McGill
package std

import (
	"fmt"
	"net"
	"strings"

	gwk "github.com/pcbuildpluscoding/cibuild/genwork/profile"
	cgp "github.com/pcbuildpluscoding/cibuild/lib/cgroup"
	cmp "github.com/pcbuildpluscoding/cibuild/lib/completion"
	crt "github.com/pcbuildpluscoding/cibuild/lib/create"
	dfv "github.com/pcbuildpluscoding/cibuild/lib/defvalue"
	fut "github.com/pcbuildpluscoding/cibuild/lib/flagutil"
	gpu "github.com/pcbuildpluscoding/cibuild/lib/gpus"
	lnx "github.com/pcbuildpluscoding/cibuild/lib/linux"
	mnt "github.com/pcbuildpluscoding/cibuild/lib/mount"
	nwk "github.com/pcbuildpluscoding/cibuild/lib/network"
	rst "github.com/pcbuildpluscoding/cibuild/lib/restart"
	rtm "github.com/pcbuildpluscoding/cibuild/lib/runtime"
	scr "github.com/pcbuildpluscoding/cibuild/lib/security"
	ult "github.com/pcbuildpluscoding/cibuild/lib/ulimit"
	vlm "github.com/pcbuildpluscoding/cibuild/lib/volume"
	vlt "github.com/pcbuildpluscoding/cibuild/lib/volumeList"
	stm "github.com/pcbuildpluscoding/cibuild/stream"
	fs "github.com/pcbuildpluscoding/genware/lib/filesystem"
	trv "github.com/pcbuildpluscoding/genware/lib/trovient"
	"github.com/pcbuildpluscoding/logroll"
	tdb "github.com/pcbuildpluscoding/trovedb/std"
	gwt "github.com/pcbuildpluscoding/types/genware"
	rwt "github.com/pcbuildpluscoding/types/runware"
	xs "github.com/pcbuildpluscoding/xstring"
	"github.com/sirupsen/logrus"
)

var logger = logroll.Get()

// -------------------------------------------------------------- //
// SetLogger
// ---------------------------------------------------------------//
func SetLogger(super *logrus.Logger) {
  logger = super
}

type Genware = gwt.Genware
type Genwork = gwt.Genwork
type GenwareVendor = gwt.GenwareVendor
type GenworkVendor = gwt.GenworkVendor
type Runware = rwt.Runware
type Trovian = tdb.Trovian
type XString = xs.XString

//------------------------------------------------------------------//
// init - register plugins
//------------------------------------------------------------------//
func init() {
  pkey := "cibuild/profile/edit"
  vendorB := NewEditProfileVendor()
  gwt.RegisterGenwork(pkey, vendorB)
  pkey = "cibuild/codegen/streamium"
  vendorC := NewCodeGenVendor(pkey)
  gwt.RegisterGenware(pkey, vendorC)
}

//----------------------------------------------------------------//
// NewCodeGenVendor
//----------------------------------------------------------------//
func NewCodeGenVendor(pkey string) GenwareVendor {
  return func(netAddr string, rw Runware) (Genware, error) {
    jobId := rw.String("JobId")
    if jobId == "" {
      return nil, fmt.Errorf("jobId is required")
    } 
    connex, err := newTrovian(netAddr, rw.String("JobId"))
    if err != nil {
      return nil, err
    }
    switch action := rw.String("Action"); action {
    case "Generate":
      if !rw.HasKeys("FileName","ParamValue") {
        return nil, fmt.Errorf("FileName and ParamValue are required parameters")
      }
      err := resolveReqParams(connex, rw)
      if err != nil {
        return nil, err
      }
      stm.SetLogger(logger)
      switch paramKey := rw.String("FileName"); paramKey {
      case "cgroup":
        cgp.SetLogger(logger)
        return cgp.StreamGen, nil
      case "completion":
        cmp.SetLogger(logger)
        return cmp.StreamGen, nil
      case "create":
        crt.SetLogger(logger)
        return crt.StreamGen, nil
      case "defvalue":
        dfv.SetLogger(logger)
        return dfv.StreamGen, nil
      case "flagutil":
        fut.SetLogger(logger)
        return fut.StreamGen, nil
      case "gpus":
        gpu.SetLogger(logger)
        return gpu.StreamGen, nil
      case "linux":
        lnx.SetLogger(logger)
        return lnx.StreamGen, nil
      case "mount":
        mnt.SetLogger(logger)
        return mnt.StreamGen, nil
      case "network":
        nwk.SetLogger(logger)
        return nwk.StreamGen, nil
      case "restart":
        rst.SetLogger(logger)
        return rst.StreamGen, nil
      case "runtime":
        rtm.SetLogger(logger)
        return rtm.StreamGen, nil
      case "security":
        scr.SetLogger(logger)
        return scr.StreamGen, nil
      case "ulimit":
        ult.SetLogger(logger)
        return ult.StreamGen, nil
      case "volume":
        vlm.SetLogger(logger)
        return vlm.StreamGen, nil
      case "volumeList":
        vlt.SetLogger(logger)
        return vlt.StreamGen, nil
      default:
        return nil, fmt.Errorf("invalid StreamGen parameter : %s", paramKey)
      }

    default:
      return nil, fmt.Errorf("unsupported %s action : %s", pkey, action)
    }
  }
}

//----------------------------------------------------------------//
// resolveReqParams
//----------------------------------------------------------------//
func resolveReqParams(connex *Trovian, rw Runware) error {
  filePath, err := fs.ResolvePath(connex, rw.String("ParamValue"))
  if err != nil {
    return err
  }
  configKey := rw.String("FileName")
  pv, err := trv.MarkupToRunware(filePath)
  if err != nil {
    return err
  }
  if !pv.HasKeys(configKey) {
    return fmt.Errorf("streamium config key : %s does not exist in runware", configKey)
  }
  // get the module configuration
  pv = pv.SubNode(configKey)
  // get the inputFile passed to the parser
  inputFile, err := fs.ResolvePath(connex, rw.String("InputFile"))
  if err != nil {
    return err
  }
  // replace the inputFile markup with the module defined input filename
  inputFile = strings.Replace(inputFile, "<inputFile>", pv.String("InputFile"), 1)
  rw.Set("InputFile", inputFile)
  pv = pv.SubNode("Streamium")
  sn := rw.SubNode("Streamium")
  inputFile, err = fs.ResolvePath(connex, sn.String("InputFile"))
  if err != nil {
    return err
  }
  inputFile = strings.Replace(inputFile, "<inputFile>", pv.String("InputFile"), 1)
  // set the resolved filepath in the runware for Streamium consumption
  sn.Set("InputFile", inputFile)

  var outputFile string
  if strings.HasPrefix(pv.String("OutputFile"), "trovedb") {
    // a module defined absolute output pathname overrides the default runware parameter
    outputFile, err = fs.ResolvePath(connex, pv.String("OutputFile"))
    if err != nil {
      return err
    }
  } else {
    outputFile, err = fs.ResolvePath(connex, sn.String("OutputFile"))
    if err != nil {
      return err
    }
    outputFile = strings.Replace(outputFile, "<outputFile>", pv.String("OutputFile"), 1)
  }
  // set the resolved filepath in the runware for Streamium consumption
  sn.Set("OutputFile", outputFile)
  // set the Streamium parameter subNode in the runware
  rw.Set("Streamium", sn.AsMap())
  logger.Debugf("StreamGen vendor has resolved parameters : %v", sn.AsMap())
  return nil
}

//----------------------------------------------------------------//
// NewEditProfileVendor
//----------------------------------------------------------------//
func NewEditProfileVendor() GenworkVendor {
  return func(troveAddr string, rw Runware) (Genwork, error) {
    connex, err := newTrovian(troveAddr, rw.String("BucketName"))
    if err != nil {
      return nil, err
    }
    return gwk.NewProfileEditor(connex)
  }
}

// ---------------------------------------------------------------//
// NewTrovian
// ---------------------------------------------------------------//
func newTrovian(netAddr, bucket string) (*Trovian, error) {

  logger.Debugf("dialing trovedb address %s ...", netAddr)
  
  conn, err := net.Dial("tcp", netAddr)
  
  if err != nil {
    return nil, fmt.Errorf("dialing %s failed : %v", netAddr, err)
  } 

  return tdb.NewTrovian(conn, bucket)
}