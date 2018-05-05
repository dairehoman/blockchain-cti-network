package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/dairehoman/libstix2/objects"
	"github.com/hyperledger/fabric/core/chaincode/shim"
	pb "github.com/hyperledger/fabric/protos/peer"
)

// TLPGREEN -
type TLPGREEN struct {
}

// Init -
func (t *TLPGREEN) Init(stub shim.ChaincodeStubInterface) pb.Response {
	return shim.Success(nil)
}

// Invoke -
func (t *TLPGREEN) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
	fn, args := stub.GetFunctionAndParameters()
	var result string
	var err error
	if fn == "set" {
		result, err = set(stub, args)
	} else {
		result, err = get(stub, args)
	}
	if err != nil {
		return shim.Error(err.Error())
	}
	return shim.Success([]byte(result))
}

//set -
func set(stub shim.ChaincodeStubInterface, args []string) (string, error) {

	if args[8] == "green" {
		bundle := objects.NewBundle()
		ioc := objects.NewIndicator("2.0")
		ioc.SetName(args[1])
		ioc.AddLabel(args[2])
		ioc.SetValidFrom(time.Now())
		ioc.CreateKillChainPhase(args[3], args[4])
		bundle.AddObject(ioc)
		m := objects.NewMalware("2.0")
		m.SetName(args[5])
		m.AddLabel(args[6])
		m.AddLabel(args[7])
		bundle.AddObject(m)
		dm := objects.NewMarkingDefinition("2.0", args[8])
		bundle.AddObject(dm)
		i := objects.NewIdentity("2.0")
		i.AddSector(args[9])
		i.SetIdentityClass(args[10])
		i.SetName(args[11])
		bundle.AddObject(i)
		var data []byte
		data, _ = json.MarshalIndent(bundle, "", "    ")
		err := stub.PutState("bundle"+args[12], []byte(data))
		if err != nil {
			return "", fmt.Errorf("Failed to set ioc: %s", args[0])
		}
	} else {
		return "", fmt.Errorf("Contract Violation: Only TLP GREEN permiited on this channel%s", args[0])
	}

	return args[1], nil
}

// get -
func get(stub shim.ChaincodeStubInterface, args []string) (string, error) {
	if len(args) != 1 {
		return "", fmt.Errorf("Incorrect arguments. Expecting a key")
	}
	value, err := stub.GetState(args[0])
	if err != nil {
		return "", fmt.Errorf("Failed to get ioc: %s with error: %s", args[0], err)
	}
	if value == nil {
		return "", fmt.Errorf("Asset not found: %s", args[0])
	}
	return string(value), nil
}

//main -
func main() {
	if err := shim.Start(new(TLPGREEN)); err != nil {
		fmt.Printf("Error starting chaincode: %s", err)
	}
}
