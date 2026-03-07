// Custom Labels for Reimbursement Form
import Reimbursement_Patient_Training from '@salesforce/label/c.Reimbursement_Patient_Training';
import Reimbursement_Observation from '@salesforce/label/c.Reimbursement_Observation';
import Reimbursement_Select_Type from '@salesforce/label/c.Reimbursement_Select_Type';
import Reimbursement_Rate_Applied from '@salesforce/label/c.Reimbursement_Rate_Applied';
import Reimbursement_Enter_Expenses from '@salesforce/label/c.Reimbursement_Enter_Expenses';
import Reimbursement_Meals from '@salesforce/label/c.Reimbursement_Meals';
import Reimbursement_Hotels from '@salesforce/label/c.Reimbursement_Hotels';
import Reimbursement_Car_Rental from '@salesforce/label/c.Reimbursement_Car_Rental';
import Reimbursement_Train_Bus_Airfare from '@salesforce/label/c.Reimbursement_Train_Bus_Airfare';
import Reimbursement_Parking from '@salesforce/label/c.Reimbursement_Parking';
import Reimbursement_Tolls from '@salesforce/label/c.Reimbursement_Tolls';
import Reimbursement_Others from '@salesforce/label/c.Reimbursement_Others';
import Reimbursement_Miles_Travelled from '@salesforce/label/c.Reimbursement_Miles_Travelled';
import Reimbursement_Mileage_Rate from '@salesforce/label/c.Reimbursement_Mileage_Rate';
import Reimbursement_Amount from '@salesforce/label/c.Reimbursement_Amount';
import Reimbursement_Hourly_Rate from '@salesforce/label/c.Reimbursement_Hourly_Rate';
import Reimbursement_Number_Of_Minutes from '@salesforce/label/c.Reimbursement_Number_Of_Minutes';
import Reimbursement_Calculated_Summary from '@salesforce/label/c.Reimbursement_Calculated_Summary';
import Reimbursement_Training_Subtotal from '@salesforce/label/c.Reimbursement_Training_Subtotal';
import Reimbursement_Hourly_Rate_Subtotal from '@salesforce/label/c.Reimbursement_Hourly_Rate_Subtotal';
import Reimbursement_Mileage_Subtotal from '@salesforce/label/c.Reimbursement_Mileage_Subtotal';
import Reimbursement_Parking_Tolls_Other from '@salesforce/label/c.Reimbursement_Parking_Tolls_Other';
import Reimbursement_Pre_Approved_Items from '@salesforce/label/c.Reimbursement_Pre_Approved_Items';
import Reimbursement_Grand_Total from '@salesforce/label/c.Reimbursement_Grand_Total';
import Reimbursement_Comments from '@salesforce/label/c.Reimbursement_Comments';
import Reimbursement_Cancel from '@salesforce/label/c.Reimbursement_Cancel';
import Reimbursement_Save_As_Draft from '@salesforce/label/c.Reimbursement_Save_As_Draft';
import Reimbursement_Next from '@salesforce/label/c.Reimbursement_Next';
import Reimbursement_Submit_For_Approval from '@salesforce/label/c.Reimbursement_Submit_For_Approval';
import Reimbursement_Select_Training from '@salesforce/label/c.Reimbursement_Select_Training';
import Reimbursement_Select_Observation from '@salesforce/label/c.Reimbursement_Select_Observation';
import Reimbursement_Available_Trainings from '@salesforce/label/c.Reimbursement_Available_Trainings';
import Reimbursement_Available_Observations from '@salesforce/label/c.Reimbursement_Available_Observations';
import Reimbursement_Training_Number from '@salesforce/label/c.Reimbursement_Training_Number';
import Reimbursement_Account from '@salesforce/label/c.Reimbursement_Account';
import Reimbursement_Training_Type from '@salesforce/label/c.Reimbursement_Training_Type';
import Reimbursement_Training_Method from '@salesforce/label/c.Reimbursement_Training_Method';
import Reimbursement_Training_Conducted_Date from '@salesforce/label/c.Reimbursement_Training_Conducted_Date';
import Reimbursement_Training_Completion_Date from '@salesforce/label/c.Reimbursement_Training_Completion_Date';
import Reimbursement_CSM from '@salesforce/label/c.Reimbursement_CSM';
import Reimbursement_Name from '@salesforce/label/c.Reimbursement_Name';
import Reimbursement_Observation_Date from '@salesforce/label/c.Reimbursement_Observation_Date';
import Reimbursement_Observation_Type from '@salesforce/label/c.Reimbursement_Observation_Type';
import Reimbursement_Trainer_Name from '@salesforce/label/c.Reimbursement_Trainer_Name';
import Reimbursement_Contract_Level_1 from '@salesforce/label/c.Reimbursement_Contract_Level_Level_1';
import Reimbursement_Contract_Level_2 from '@salesforce/label/c.Reimbursement_Contract_Level_Level_2';
import Reimbursement_Contract_Level_3 from '@salesforce/label/c.Reimbursement_Contract_Level_Level_3';
import Reimbursement_Educator_Type_CCT from '@salesforce/label/c.Reimbursement_Educator_Type_CCT';
import Reimbursement_Educator_Type_CPT from '@salesforce/label/c.Reimbursement_Educator_Type_CPT';
import Observation_Certificate_Error_Message from '@salesforce/label/c.Observation_Certificate_Error_Message';
import Observation_Contract_Error_Message from '@salesforce/label/c.Observation_Contract_Error_Message';
import Training_Certificate_Error_Message from '@salesforce/label/c.Training_Certificate_Error_Message';
import Training_Contract_Error_Message from '@salesforce/label/c.Training_Contract_Error_Message';

import No_Records from '@salesforce/label/c.Reimbursement_No_Records'

// Export all labels as a single object
export const LABELS = {
    Patient_Training: Reimbursement_Patient_Training,
    Observation: Reimbursement_Observation,
    Select_Type: Reimbursement_Select_Type,
    Rate_Applied: Reimbursement_Rate_Applied,
    Enter_Expenses: Reimbursement_Enter_Expenses,
    Meals: Reimbursement_Meals,
    Hotels: Reimbursement_Hotels,
    Car_Rental: Reimbursement_Car_Rental,
    Train_Bus_Airfare: Reimbursement_Train_Bus_Airfare,
    Parking: Reimbursement_Parking,
    Tolls: Reimbursement_Tolls,
    Others: Reimbursement_Others,
    Miles_Travelled: Reimbursement_Miles_Travelled,
    Mileage_Rate: Reimbursement_Mileage_Rate,
    Amount: Reimbursement_Amount,
    Hourly_Rate: Reimbursement_Hourly_Rate,
    Number_Of_Minutes: Reimbursement_Number_Of_Minutes,
    Calculated_Summary: Reimbursement_Calculated_Summary,
    Training_Subtotal: Reimbursement_Training_Subtotal,
    Hourly_Rate_Subtotal: Reimbursement_Hourly_Rate_Subtotal,
    Mileage_Subtotal: Reimbursement_Mileage_Subtotal,
    Parking_Tolls_Other: Reimbursement_Parking_Tolls_Other,
    Pre_Approved_Items: Reimbursement_Pre_Approved_Items,
    Grand_Total: Reimbursement_Grand_Total,
    Comments: Reimbursement_Comments,
    Cancel: Reimbursement_Cancel,
    Save_As_Draft: Reimbursement_Save_As_Draft,
    Next: Reimbursement_Next,
    Submit_For_Approval: Reimbursement_Submit_For_Approval,
    Select_Training: Reimbursement_Select_Training,
    Select_Observation: Reimbursement_Select_Observation,
    Available_Trainings: Reimbursement_Available_Trainings,
    Available_Observations: Reimbursement_Available_Observations,
    Training_Number: Reimbursement_Training_Number,
    Account: Reimbursement_Account,
    Training_Type: Reimbursement_Training_Type,
    Training_Method: Reimbursement_Training_Method,
    Training_Conducted_Date: Reimbursement_Training_Conducted_Date,
    Training_Completion_Date: Reimbursement_Training_Completion_Date,
    CSM: Reimbursement_CSM,
    Name: Reimbursement_Name,
    Observation_Date: Reimbursement_Observation_Date,
    Observation_Type: Reimbursement_Observation_Type,
    Trainer_Name: Reimbursement_Trainer_Name,
    No_Records: No_Records,
    Reimbursement_Contract_Level_1 : Reimbursement_Contract_Level_1,
    Reimbursement_Contract_Level_2 : Reimbursement_Contract_Level_2,
    Reimbursement_Contract_Level_3 : Reimbursement_Contract_Level_3,
    Reimbursement_Educator_Type_CCT : Reimbursement_Educator_Type_CCT,
    Reimbursement_Educator_Type_CPT : Reimbursement_Educator_Type_CPT,
    Observation_Certificate_Error_Message : Observation_Certificate_Error_Message,
    Observation_Contract_Error_Message : Observation_Contract_Error_Message,
    Training_Certificate_Error_Message : Training_Certificate_Error_Message ,
    Training_Contract_Error_Message : Training_Contract_Error_Message




};

// OPTIONS constant using labels
export const OPTIONS = {
    Patient_Training: Reimbursement_Patient_Training,
    Observation: Reimbursement_Observation
};

export const columns = {
    training: [
        { label: Reimbursement_Training_Number, fieldName: 'name', sortable: true },
        { label: Reimbursement_Account, fieldName: 'accountName', sortable: true },
        { label: Reimbursement_Training_Type, fieldName: 'type', sortable: true },
        { label: Reimbursement_Training_Method, fieldName: 'trainingMethod', sortable: true },
        {
            label: Reimbursement_Training_Conducted_Date, fieldName: 'trainingConductedDate', sortable: true
        },
        {
            label: Reimbursement_Training_Completion_Date, fieldName: 'completionDate', sortable: true
        },
        {
            label: Reimbursement_CSM, fieldName: 'csmName', sortable: true
        },
    ],
    observation: [
        { label: Reimbursement_Name, fieldName: 'name', sortable: true },
        { label: Reimbursement_Observation_Date, fieldName: 'completionDate', sortable: true },
        { label: Reimbursement_Observation_Type, fieldName: 'type', sortable: true },
        { label: Reimbursement_Trainer_Name, fieldName: 'trainerName', sortable: true },
    ]
}