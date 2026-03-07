@IsTest
private class FlowDmlUtilityTest {
    /**
     * @description This method tests the handleDmlUpdate method of the FlowDmlUtility class.
     */
    @IsTest
    private static void handleDmlUpdate(){
        List<Lead> leadList = TestDataFactory.getLeads(10,null);
        List<FlowDmlUtility.FlowInput> inputList = new List<FlowDmlUtility.FlowInput>();
        For(Integer i=0;i<10;i++){
            FlowDmlUtility.FlowInput input = new FlowDmlUtility.FlowInput();
            input.isDelete = false;
            input.isCreate = false;
            input.isUpdate = true;
            input.recordList = leadList;
            input.identifier = 'Test'+i;
            input.objectName = 'Lead';
            inputList.add(input);
        }
        FlowDmlUtility.FlowInput input = new FlowDmlUtility.FlowInput();
            input.isDelete = false;
            input.isCreate = false;
            input.isUpdate = true;
            input.identifier = 'Test';
            input.objectName = 'Lead';
        inputList.add(input);
        
        List<FlowDmlUtility.FlowOutput> outputList = FlowDmlUtility.handleDML(inputList);
        Assert.isTrue(outputList.size() > 0,'Output list should not be empty');
    }
    
    /**
     * @description This method tests the handleDmlCreate method of the FlowDmlUtility class.
     */
    @IsTest
    private static void handleDmlCreate(){
        List<Lead> leadList = TestDataFactory.getLeads(10,null);
        List<FlowDmlUtility.FlowInput> inputList = new List<FlowDmlUtility.FlowInput>();
        For(Integer i=0;i<10;i++){
            FlowDmlUtility.FlowInput input = new FlowDmlUtility.FlowInput();
            input.isDelete = false;
            input.isCreate = true;
            input.isUpdate = false;
            input.recordList = leadList;
            input.identifier = 'Test'+i;
            input.objectName = 'Lead';
            inputList.add(input);
        }
        List<FlowDmlUtility.FlowOutput> outputList = FlowDmlUtility.handleDML(inputList);
        Assert.areEqual(outputList.size(), 1, 'Output list should not be empty');
    }
    
    /**
     * @description This method tests the handleDmlDelete method of the FlowDmlUtility class.
     */
    @IsTest
    private static void handleDmlDelete(){
        Lead leadRecord = TestDataFactory.getLead(null);
        List<FlowDmlUtility.FlowInput> inputList = new List<FlowDmlUtility.FlowInput>();
        For(Integer i=0;i<1;i++){
            FlowDmlUtility.FlowInput input = new FlowDmlUtility.FlowInput();
            input.isDelete = true;
            input.isCreate = true;
            input.isUpdate = false;
            input.recordList = new List<SObject>{leadRecord};
            input.identifier = 'Test'+i;
            input.objectName = 'Lead';
            inputList.add(input);
        }
        List<FlowDmlUtility.FlowOutput> outputList = FlowDmlUtility.handleDML(inputList);
        Assert.areEqual(outputList.size(), 1, 'Output list should not be empty');
    }
}