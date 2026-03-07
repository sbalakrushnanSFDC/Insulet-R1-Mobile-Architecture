/**
* @author      : Shashank Nigam
* @created Date: 3rd Nov 2025
* @description : Utility Class for Flows to Perform Partial DML, Upsert on List of Records and handle DML errors gracefully by 
* logging errors or providing list of errors back to flow for processing.
* @story Number: NGPSTE-627
* =========================== Logs ==============================
* Version      Modified Date       Modified By         Brief Note
* v1.0.0       3rd Nov 2025       Shashank Nigam      Initial Version
*/
public without sharing class FlowDmlUtility {
    /**
     * @description This class is used to pass input to the handleDML method.
     */
    public class FlowInput{
        @InvocableVariable(defaultValue='false') public Boolean isCreate;
        @InvocableVariable(defaultValue='false') public Boolean isUpdate;
        @InvocableVariable(defaultValue='false') public Boolean isDelete;
        @InvocableVariable public List<SObject> recordList;
        @InvocableVariable(required=true) public String identifier;
        @InvocableVariable(required=true) public String objectName;
    }
    /**
     * @description This class is used to return output from the handleDML method.
     */
    public class FlowOutput{
        @InvocableVariable public String objectName;
        @InvocableVariable public String errorLog;
    }
    
    private static Map<String,String> recordVsIdentifierMap = new Map<String,String>();
    private static Map<String,List<String>> result = new Map<String,List<String>>();
    
    /**
     * @description This method takes in a list of FlowInput objects and performs DML operations on the records.
     * @param details List of FlowInput objects
     * @return List of FlowOutput objects
     */
    @InvocableMethod(label='Partial DML Operation')
    public static List<FlowOutput> handleDML(List<FlowInput> details){
        List<FlowOutput> returnList = new List<FlowOutput>();
        try{
            List<SObject> impactedRecords = new List<SObject>();
            for(FlowInput f: details){
                if(f.recordList == null) {
                    continue;
                }
                for(SObject s: f.recordList){
                    impactedRecords.add(s);
                    recordVsIdentifierMap.put(s.Id,f.identifier);
                }
            }
            if(details[0].isCreate){
                handleError(Database.insert(impactedRecords, false),'create');
            } 
            if(details[0].isUpdate){
                handleError(Database.update(impactedRecords, false),'update');
            } 
            if(details[0].isDelete){
                handleError(Database.delete(impactedRecords, false));
            }  
            for(FlowInput f: details){
                FlowOutput fo = new FlowOutput();
                if(result.containsKey(f.identifier)){
                    fo.objectName = f.objectName;
                    fo.errorLog = 'For Object: '+ f.objectName + '\n'+ String.join(result.get(f.identifier),'\n\t');
                }
                else{
                    fo.objectName = '';
                    fo.errorLog = '';
                }
                returnList.add(fo);
            }
        }
        catch(Exception e){
            FlowOutput fo = new FlowOutput();
            fo.errorLog = e.getMessage()+e.getLineNumber();
            returnList.add(fo);
        }
        return returnList;
    }
    /**
     * @description This method handles the errors returned from the DML operations.
     * @param srList List of SaveResult objects
     * @param operation String representing the operation performed
     */
    @testVisible
    private static void handleError(Database.SaveResult[] srList,String operation){
        for (Database.SaveResult sr : srList) {
            if (!sr.isSuccess()) { 
                logError(operation,sr.getId());
            }
        }
    }
    /**
     * @description This method handles the errors returned from the DML operations.
     * @param srList List of DeleteResult objects
     */
    @testVisible
    private static void handleError(Database.DeleteResult[] srList){
        for (Database.DeleteResult sr : srList) {
            if (!sr.isSuccess()) { 
                logError('Delete',sr.getId());
            }
        }
    }
    /**
     * @description This method logs the error messages returned from the DML operations.
     * @param operation String representing the operation performed
     * @param recordId String representing the record Id
     */
    @testVisible
    private static void logError(String operation,String recordId){
        String identifier = recordVsIdentifierMap.get(recordId);
        if(result.containsKey(identifier)){
            result.get(identifier).add('Unable to '+operation+' record: '+recordId);
        }
        else{
            result.put(identifier,new List<String>{'Unable to '+operation+' record: '+recordId});
        }
    }
}