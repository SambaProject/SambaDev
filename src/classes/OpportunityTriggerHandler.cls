//AUTHOR :                      Khushman,Deomurari(161183)
//CREATED :                     7 September 2016
//LAST MODIFIED BY :     <Nityanand Wachche(161181)>
//LAST MODIFIED :          <9/12/2016>
//MODIFICATION HISTORY: Changes on Dec 2016: By 161181: To validate Questionnaire only for users having Permission Set "Win Loss Permission Set".
         
//UST:1072
//UST TITLE :Win Loss Questionnaire
      
//PURPOSE OF DEVELOPMENT: opportunity Trigger Handler
public class OpportunityTriggerHandler
{
 //test records
    public static Boolean runOnlyOnce = true;
    Integer Monthof_c_Sett;
    Integer count;
    
    /*
        * Ust No           :   UST 1386
        * Purpose          :   Chorono number field in Opportunity we have to save value 
                                "first letter of firstname + first two letters of lastname + YY + MM - 000 (resets to 000 starting of each new month)
                                first letter of firstname + first two letters of lastname + YY + MM - 001 (resets to 000 starting of each new month)
                                "
        * Last ModifiedBy  :   162487
        * Last Modified On :   08/12/2016      
    
    */
    public void OnBeforeInsert(List<Opportunity> newOpportunities){
     // no bypass trigger it will run every time 
         //calculate_chorono_Number(newOpportunities);
         // no bypass trigger it will run every time 
         
         Chrono_Number.calculate_Chrono_Number(newOpportunities);
    }
    
    //Ust 1332 :- To Prevent french user to create opportunity on virtual account 
   
    //Ust 1332 :- created a new method to Prevent french user to create opportunity on virtual account   
    public void preventFrenchUserToCreateOpp(List<Opportunity> lstOpportunity){
       Set<id>accSetid=new Set<id>();
        for(Opportunity opp: lstOpportunity){
            //Check Account id should not null or blank on creation/edition of opportunity. 
            if(opp.accountid!=null)
                accSetid.add(opp.accountid);
        }
        //Create a map using of soql query to get accounts.
        Map<id,Account>mapAcc=new Map<id,Account>([Select id,Name,ParentId, AccountSource,RCE_ID__c, iSell__OSKeyID__c from Account where id In: accSetid]);
                                                                                                      
        for(Opportunity opp: lstOpportunity){
            if(mapAcc.containskey(opp.accountid)){ 
                //To verify conditions for  french virtual account.
                if(mapAcc.get(opp.accountid).RCE_ID__c==null && mapAcc.get(opp.accountid).AccountSource=='SMB_France'){                      
                   //Display error message in both language english and frecnh by creating a custom Label.
                   opp.addError(System.Label.error_mesage);                     
                }
            }
        }    
    }
    
    public void OnAfterInsert(List<Opportunity> newOpportunities, Map<ID, Opportunity> newOpportunityMap){}
    
    public void OnBeforeUpdate(List<Opportunity> oldOpportunities, List<Opportunity> newOpportunities, 
    Map<ID, Opportunity> oldOpportunityMap, Map<ID, Opportunity> newOpportunityMap){
        //UST-01246: Display error when no partners are added and Opportunity without checkbox is unchecked - START
        //Don't run code if OpportunityTrigger.validatePartners is bypassed in Bypass Trigger of current user
         if(PAD.canTrigger('OpportunityTrigger.validatePartners'))
         {
        
            //Consider only Opportunities which went to Stage>2 from 1st or 2nd Stage
            List<Opportunity> newOpportunitiesToValidate=new List<Opportunity>();

            for (Opportunity currNewOpp: newOpportunities)
            {
             // [9 DEC 2016] [Changes are done by 161181][UST 1072][To validate Questionnaire only for users having Permission Set "Win Loss Permission Set"]
           //  list<PermissionSetAssignment> user_a =[select Assignee.id from PermissionSetAssignment where PermissionSet.Name =:System.Label.WinLossPermissionSet and Assignee.id=:UserInfo.getUserId() ];  
         
           //   system.debug('userinfo'+UserInfo.getUserId());
           //   system.debug('user_value'+user_a);
          // [9 DEC 2016] [Changes are done by 161181][UST 1072][Changes on Dec 2016: By 161181: To validate Questionnaire only for users having Permission Set "Win Loss Permission Set"]
                if (currNewOpp.SMB_OPP_stage_nb__c>2) 
                {
                    newOpportunitiesToValidate.add(newOpportunityMap.get(currNewOpp.id));
                  //  system.debug('opportunity_validate'+newOpportunitiesToValidate);
                }
            }

            //Validate these opportunities
            validatePartners(newOpportunities, newOpportunitiesToValidate, newOpportunityMap);
        }
        //UST-01246 - END
        
        //UST-01249: To validate Parent Opportunity ID is pointing to some already existing Opportunity
        if(PAD.canTrigger('OpportunityTrigger.validatePublicOppID')){
            validatePublicOppID(newOpportunities, newOpportunityMap);
        }
        // [28 Sep 2016]UST-01072:(161181) 
         //UST-01072: To restrict Save when validation of any Opp falling in criteria is not completed
        if(PAD.canTrigger('OpportunityTrigger.validateQuestionnaires')){
      // [9DEC 2016] [Changes are done by 161181][UST 1072][To validate Questionnaire only for users having Permission Set "Win Loss Permission Set"]
       //   list<PermissionSetAssignment> user_a =[select Assignee.id from PermissionSetAssignment where PermissionSet.Name =:System.Label.WinLossPermissionSet and Assignee.id=:UserInfo.getUserId() ];  
         
        //  system.debug('userinfo'+UserInfo.getUserId());
         // system.debug('user_value'+user_a);
          // [9 DEC 2016] [Changes are done by 161181][UST 1072][To validate Questionnaire only for users having Permission Set "Win Loss Permission Set"]


            
                validateQuestionnaires(newOpportunities, newOpportunityMap);

           
        }

    }
    
    public void OnAfterUpdate(List<Opportunity> oldOpportunities, List<Opportunity> newOpportunities, 
                                Map<ID, Opportunity> oldOpportunityMap, Map<ID, Opportunity> newOpportunityMap)
    {
        List<ConnectApi.BatchInput> batchInputs = new List<ConnectApi.BatchInput>();
        String amountFieldLabel = Schema.Opportunity.fields.Amount.getDescribe().getLabel();
        
        List<Messaging.SingleEmailMessage> mailList = new List<Messaging.SingleEmailMessage>();
        List<EmailTemplate> templateList = [SELECT Id, HtmlValue, Subject FROM EmailTemplate WHERE name = 'SMB_Opp_Old_Owner_Notification' limit 1];
        
        for(Opportunity opp : newOpportunities)
        {
            
            if(opp.Amount != oldOpportunityMap.get(opp.Id).Amount)
            {
                if(OpportunityAfterUpdateHelper.addchatterFeedOnAmountChange
                    (opp.Amount, oldOpportunityMap.get(opp.Id).Amount))
                {
                    String message = ' changed '+amountFieldLabel+' from '+opp.CurrencyIsoCode+' '+oldOpportunityMap.get(opp.Id).Amount+
                                        ' to '+opp.CurrencyIsoCode+' '+opp.Amount;
                    if(oldOpportunityMap.get(opp.Id).Amount == null)
                    {
                        message = ' changed '+amountFieldLabel+' from a blank value to '+opp.CurrencyIsoCode+' '+opp.Amount;
                    }                                        
                    batchInputs.add(SMB_Chatter_Helper.createFeedList
                    (opp.Id, null, message));
                }
            }
            
            
            if(opp.OwnerId != oldOpportunityMap.get(opp.Id).OwnerId)
            {
                String subject = templateList[0].Subject.replace('{!Opportunity.Name}', opp.Name);
                String bdy = templateList[0].HtmlValue;
                bdy = bdy.replace('{!Opportunity.Name}', opp.Name);
                bdy = bdy.replace('{!Opportunity.Id}', opp.Id);
                bdy = bdy.replace('{!URL}', OpportunityAfterUpdateHelper.getURL());                                
                mailList.add(SendingEmailHelper.processEmail(oldOpportunityMap.get(opp.Id).OwnerId, subject, bdy, null, null));
            }
            
        }
        
        if(batchInputs.size()>0){
            SMB_Chatter_Helper.postBulkChatterFeed(batchInputs);
        }
        if(mailList.size()>0){
            Messaging.sendEmail(mailList);
        }
        
        OpportunityTriggerHandler.runOnlyOnce = false;
    }
    
    public void OnBeforeDelete(List<Opportunity> oldOpportunities, Map<ID, Opportunity> oldOpportunityMap){}
    
    public void OnAfterDelete(List<Opportunity> oldOpportunities, Map<ID, Opportunity> oldOpportunityMap){}
    
    public void OnUndelete(List<Opportunity> newOpportunities){}
    
    //UST-01246: Display error when no partners are added and Opportunity without checkbox is unchecked
    public void validatePartners(List<Opportunity> newOpportunities, List<Opportunity> newOpportunitiesToValidate, Map<ID, Opportunity> newOpportunityMap)
    {
        //Get no of partners in each Opportunity about to be updated/inserted
        List<AggregateResult> oppPartners = [select OpportunityId, count(id) noOfPartners from OpportunityPartner where OpportunityId IN :newOpportunities GROUP BY OpportunityId];
        // [9 DEC 2016] [Changes are done by 161181][UST 1072][To validate Questionnaire only for users having Permission Set "Win Loss Permission Set"]
        //list<PermissionSetAssignment> user_a =[select Assignee.id from PermissionSetAssignment where PermissionSet.Name =:System.Label.WinLossPermissionSet and Assignee.id=:UserInfo.getUserId() ];  
        Map<Id, Integer> partnerCounts=new Map<Id, Integer>();
        for (AggregateResult ar: oppPartners)
        {
         // [9 DEC 2016][Changes are done by 161181][UST 1072][To validate Questionnaire only for users having Permission Set "Win Loss Permission Set"]

        
            partnerCounts.put((Id)ar.get('OpportunityId'), (Integer)ar.get('noOfPartners'));
        }
        
        //Check for all Opportunites if 'Opportunity without Partner' is checked even when Partners are added 
        for (Opportunity currOpp: newOpportunities)
        {
            //Add error if checkbox 'Opportunity without Partner' is checked even when Partners are added
            if (partnerCounts.keySet().contains(currOpp.Id) && currOpp.Smb_opportunity_without_partner__c==true)
            {
                    currOpp.addError(Label.SMB_Checked_With_Partner);
            }
        }

        //Check for Stage changed Opportunities if they don't ave any partners and checkbox 'Opportunity without Partner' is also unchecked
        for (Opportunity currOpp: newOpportunitiesToValidate)
        {
            //Add error if checkbox 'Opportunity without Partner' is also unchecked
            if (!partnerCounts.keySet().contains(currOpp.Id) && currOpp.Smb_opportunity_without_partner__c==false )
            {
                   
                    currOpp.addError(Label.SMB_No_Partner);
                    
            }
        }
    }
    
    public void validatePublicOppID(List<Opportunity> newOpportunities, Map<ID, Opportunity> newOpportunityMap)
    {
    //SMB_OPP_Parent_Opportunity_ID__c, SMB_OPP_Public_Opportunity_ID__c
      Map<String, List<Opportunity>> parentOppToOppMap=new Map<String, List<Opportunity>>();
      for (Opportunity opp: newOpportunities) {
        if (opp.SMB_OPP_Parent_Opportunity_ID__c!=null && opp.SMB_OPP_Parent_Opportunity_ID__c!=''){
            if (!parentOppToOppMap.keySet().contains(opp.SMB_OPP_Parent_Opportunity_ID__c)){
                parentOppToOppMap.put(opp.SMB_OPP_Parent_Opportunity_ID__c, new List<Opportunity>());
            }
                parentOppToOppMap.get(opp.SMB_OPP_Parent_Opportunity_ID__c).add(opp);
        }
      }
      
      List<Opportunity> parentOpps=[select SMB_OPP_Public_Opportunity_ID__c from Opportunity where SMB_OPP_Public_Opportunity_ID__c IN :parentOppToOppMap.keySet()];
      Set<String> parentpublicIDs=new Set<String>();
      for (Opportunity parentOpp: parentOpps){
          parentpublicIDs.add(parentOpp.SMB_OPP_Public_Opportunity_ID__c);
      }
      
      for (String publicId: parentOppToOppMap.keySet()) {
        if (!parentpublicIDs.contains(publicId)){
            for (Opportunity opp: parentOppToOppMap.get(publicId)) {
                opp.SMB_OPP_Parent_Opportunity_ID__c.addError(Label.SMB_Invalid_ParentOppID);
            }
        }
      }
      
    }
   //  [Sep2016]UST-01072(161181): To restrict Save when validation of any Opp falling in criteria is not completed
     public void validateQuestionnaires(List<Opportunity> newOpportunities, Map<ID, Opportunity> newOpportunityMap)
     {
        Set<Opportunity> oppSets=new Set<Opportunity>();
        Map<String, Decimal> isoCodes=new Map<String, Decimal>();
        
        //Avoiding check for Opportunities having field "All Questionnaire Validated check" checked.
        for (Opportunity opp: newOpportunities){
          //  if (!opp.SMB_All_Questionnaire_Validated__c) {
                oppSets.add(opp);
                isoCodes.put(opp.currencyIsoCode, 0);
           // }
        }

        //Getting Currency conversion rates
        List<CurrencyType> isoCodeRates = [SELECT IsoCode,ConversionRate FROM CurrencyType where IsoCode IN :isoCodes.keySet()];
        for (CurrencyType currCurrencyType: isoCodeRates){
            isoCodes.put(currCurrencyType.IsoCode, currCurrencyType.ConversionRate);
        }
        
        

        //Getting criterias of required Questionnaires
        List<Criteria__c> criteriaList=[select id, Smb_Criteria_S_NO__c, Smb_Criteria_Condition__c,Smb_Criteria_Field_concerned__c, Smb_criteria_questionnaire__c, Smb_Criteria_Type_of_the_value__c,
                Smb_Criteria_Value__c,SMB_criteria_Questionnaire__r.SMB_Questionnaire_Object_concerned__c,SMB_criteria_Questionnaire__r.SMB_Questionnaire_Name__c,SMB_criteria_Questionnaire__r.SMB_Questionnaire_Filter_Condition__c from Criteria__c where smb_criteria_Questionnaire__r.SMB_Questionnaire_Object_concerned__c='Opportunity'];
                
        //Preparing Criteria Map to provide as input to parser method
        Map<Id, Map<Integer, Criteria__c>> quesCritMap=new Map<Id, Map<Integer, Criteria__c>>();
        Map<Id, Questionnaire__c> quesMap=new Map<Id, Questionnaire__c>();
        for (Criteria__c currCriteria: criteriaList){
            if (!quesMap.keySet().contains(currCriteria.Smb_criteria_questionnaire__c)){
                if (currCriteria.smb_criteria_Questionnaire__r.SMB_Questionnaire_Filter_Condition__c!=null && currCriteria.smb_criteria_Questionnaire__r.SMB_Questionnaire_Filter_Condition__c!=''){
                    quesMap.put(currCriteria.Smb_criteria_questionnaire__c,
                        new Questionnaire__c(id=currCriteria.Smb_criteria_questionnaire__c,
                                          name=currCriteria.smb_criteria_Questionnaire__r.SMB_Questionnaire_Name__c,
                                          SMB_Questionnaire_Filter_Condition__c=currCriteria.smb_criteria_Questionnaire__r.SMB_Questionnaire_Filter_Condition__c));
                }
            }
            if (!quesCritMap.keySet().contains(currCriteria.Smb_criteria_questionnaire__c)){
                quesCritMap.put(currCriteria.Smb_criteria_questionnaire__c, new Map<Integer, Criteria__c>());
            }
            quesCritMap.get(currCriteria.Smb_criteria_questionnaire__c).put(Integer.valueOf(currCriteria.Smb_Criteria_S_NO__c), currCriteria);
        }
        
        //Evaluating criteria for each record for each Questionnaire getting updated and having field "All Questionnaire Validated" unchecked
        for(Id quesId: quesMap.keySet()){
            for (Opportunity opp: oppSets){
                //Evaluating Questionnaires only which are not already validated for this record
                if (opp.SMB_Questionnaire_list__c==null || !opp.SMB_Questionnaire_list__c.contains('Validate-'+String.valueOf(quesId).substring(0,15))){
                    //Evaluate criteria for this record and questionnaire
                    Boolean pass = parseHelper.evalStr(quesMap.get(quesId).SMB_Questionnaire_Filter_Condition__c, quesCritMap.get(quesId), opp, isoCodes.get(opp.CurrencyIsoCode));
                    //Provide error when record falls in the criteria and questionnaire ssociated with that criteria is not validated
                    if (pass){
                        //opp.addError('Please validate Questionnaire '+quesMap.get(quesId).name+' to do the required change.');
                        opp.addError(Label.CL_046_Quessionnaire_Mandatory_ErrMsg.replace('<QNAME>', quesMap.get(quesId).name));
                    }
                }
            }
        }
        

    }
}