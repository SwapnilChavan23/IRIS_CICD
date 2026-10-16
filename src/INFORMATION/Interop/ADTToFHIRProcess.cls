/// Custom Business Process that converts ADT HL7 v2 messages to FHIR R4
/// using the InterSystems native HL7 -> SDA3 -> FHIR pipeline.
/// 
/// Flow:
///   1. Receives EnsLib.HL7.Message from the Routing Rule
///   2. Converts HL7 -> SDA3 using HS.Gateway.HL7.HL7ToSDA3
///   3. Sends SDA3 to HS.FHIR.DTL.Util.HC.SDA3.FHIR.Process (built-in)
///   4. Built-in process outputs FHIR R4 Bundle -> Out_REST Operation
/// 
/// Setup in Production:
///   - Add this class as a Business Process
///   - Set FHIRTarget to the name of your HS.FHIR.DTL.Util.HC.SDA3.FHIR.Process item
///   - The built-in FHIR process will forward to Out_REST automatically
Class INFORMATION.Interop.ADTToFHIRProcess Extends Ens.BusinessProcess
{

/// Name of the built-in SDA3-to-FHIR process in your production
/// Default: FHIR_SDA3_Process (update to match your production item name)
Property FHIRTarget As %String [ InitialExpression = "FHIR_SDA3_Process" ];

Parameter SETTINGS = "FHIRTarget:Target";

Method OnRequest(pRequest As EnsLib.HL7.Message, Output pResponse As Ens.Response) As %Status
{
    set tSC = $$$OK

    try {
        $$$LOGINFO("ADTToFHIR.Process: Received HL7 message - " _ pRequest.Name)

        // Step 1: Convert HL7 v2 message to SDA3 XML string
        set tSC = ##class(HS.Gateway.HL7.HL7ToSDA3).GetSDA(pRequest, .tSDAString)
        if $$$ISERR(tSC) {
            $$$LOGERROR("HL7 to SDA3 conversion failed: " _ $system.Status.GetErrorText(tSC))
            quit
        }

        if tSDAString = "" {
            $$$LOGERROR("SDA3 output is empty - check HL7 message structure")
            quit
        }

        $$$LOGINFO("SDA3 conversion successful, sending to FHIR process")

        // Step 2: Wrap SDA3 in a StreamContainer and send to built-in FHIR process
        set tStream = ##class(Ens.StreamContainer).%New(tSDAString)
        set tSC = ..SendRequestSync(..FHIRTarget, tStream, .tFHIRResponse)
        if $$$ISERR(tSC) {
            $$$LOGERROR("SDA3 to FHIR conversion failed: " _ $system.Status.GetErrorText(tSC))
            quit
        }

        $$$LOGINFO("FHIR Bundle generated and forwarded to target operation")

    } catch ex {
        set tSC = ex.AsStatus()
        $$$LOGERROR("Exception in ADTToFHIR.Process: " _ $system.Status.GetErrorText(tSC))
    }

    quit tSC
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="EnsLib.HL7.Message">
        <Method>OnRequest</Method>
    </MapItem>
</MapItems>
}

Storage Default
{
<Data name="ADTToFHIRProcessDefaultData">
<Subscript>"ADTToFHIRProcess"</Subscript>
<Value name="1">
<Value>FHIRTarget</Value>
</Value>
</Data>
<DefaultData>ADTToFHIRProcessDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

