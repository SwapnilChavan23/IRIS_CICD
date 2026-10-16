/// 
Class INFORMATION.DEV.RoutingRule Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="EnsLib.HL7.MsgRouter.RoutingEngine" production="INFORMATION.DEV">
<ruleSet name="Sample Rule" effectiveBegin="" effectiveEnd="">
<rule name="">
<constraint name="source" value="HL7FileService"></constraint>
<when condition="1" comment="">
<send transform="" target="HL7FileOperation"></send>
</when>
</rule>
<rule name="RouteADTOnly">
<constraint name="msgClass" value="EnsLib.HL7.Message"></constraint>
<when condition="HL7.{MSH:MessageType.MessageCode}=&quot;ADT&quot;" comment="">
<send transform="" target="HL7_PatientUpdate_In"></send>
</when>
</rule>
</ruleSet>
</ruleDefinition>
}

}

