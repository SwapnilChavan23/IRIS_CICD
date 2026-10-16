/// 
Class INFORMATION.Interop.HL7InHL7OutRouterRoutingRule Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="INFORMATION.Interop.Production">
<ruleSet name="Sending Patient Updates to the FHIRStore" effectiveBegin="" effectiveEnd="">
<rule name="ADTToFHIR">
<constraint name="docCategory" value="2.1"></constraint>
<constraint name="source" value="HL7_PatientUpdate_In"></constraint>
<constraint name="docName" value="ADT_A01,ADT_A03,ADT_A04,ADT_A08,ADT_A28,ADT_A31"></constraint>
<when condition="1" comment="">
<send transform="" target="FHIR_SDA_Process_2"></send>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}
