#!/usr/bin/env python3
"""Generate comprehensive PDF from test failures consolidated report."""
from datetime import datetime
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
import json
import os

# Load org details
org_details = {}
org_json = os.path.join(os.path.dirname(__file__), "docs", "org.json")
if os.path.exists(org_json):
    try:
        with open(org_json) as f:
            data = json.load(f)
            r = data.get("result", {})
            org_details = {
                "Org ID": r.get("id", "—"),
                "Alias": r.get("alias", "—"),
                "Instance URL": r.get("instanceUrl", "—"),
                "Username": r.get("username", "—"),
                "API Version": r.get("apiVersion", "—"),
            }
    except Exception as e:
        org_details = {"Org": f"Details not available: {e}"}

DATE = datetime.now().strftime("%B %d, %Y")
CREATED_BY = "Som Balakrushnan"

# Test failure data
TABLE_DATA = [
    ["#", "Class Name", "Author", "Error Type(s)"],
    ["1", "ACRTriggerHandler_Test", "Ramesh Kumar", "System.AssertException; System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["2", "AccountContactRelationService_Test", "Copado Integration", "System.AssertException; System.DmlException / ConvertLead failed; System.DmlException / DUPLICATES_DETECTED; System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["3", "AccountDeactivationService_Test", "Copado Integration", "System.DmlException / UNABLE_TO_LOCK_ROW"],
    ["4", "AccountRelatedObjectsService_Test", "Copado Integration", "System.AssertException; System.DmlException / ConvertLead failed; System.DmlException / UNABLE_TO_LOCK_ROW"],
    ["5", "AccountService_Test", "Copado Integration", "System.DmlException / LIMIT_EXCEEDED (territory models)"],
    ["6", "AccountTriggerHandler_Test", "Copado Integration", "Unknown"],
    ["7", "AssetProcessingQueueable_FunctionalTest", "Copado Integration", "System.DmlException / LIMIT_EXCEEDED (territory models)"],
    ["8", "CaregiverRelationshipService_Test", "Copado Integration", "System.AssertException; System.DmlException / ConvertLead failed"],
    ["9", "ConsentService_Test", "Copado Integration", "System.AssertException; System.DmlException / DUPLICATES_DETECTED"],
    ["10", "ContactPointTriggerHandler_Test", "Ramesh Kumar", "System.DmlException / DELETE_FAILED (contact point consents)"],
    ["11", "ContentDocumentLinkTriggerHelper_Test", "Copado Integration", "System.DmlException / CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY; System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["12", "ContractListViewController_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["13", "DTCIncompleteTaskBatch_Test", "Copado Integration", "System.AssertException"],
    ["14", "DocusignEnvelopeStatusTimelineCtrl_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["15", "FilesRelatedListControllerTest", "Copado Integration", "System.DmlException / CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY"],
    ["16", "HPFTriggerHandler_Test", "Copado Integration", "System.AssertException"],
    ["17", "HealthCareProviderService_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["18", "IndividualService_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["19", "LeadConversionConsentMapping_Test", "Copado Integration", "System.AssertException; System.DmlException / FIELD_CUSTOM_VALIDATION_EXCEPTION"],
    ["20", "LeadConversionHandler_Test", "Copado Integration", "System.AssertException; System.DmlException / ConvertLead failed; System.DmlException / FIELD_CUSTOM_VALIDATION (Lead Converted status); System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["21", "LeadConversionHelper_Test", "Copado Integration", "System.AssertException"],
    ["22", "LeadDuplicateConversionHelper_Test", "Copado Integration", "System.AssertException; System.DmlException / APEX_DATA_ACCESS_RESTRICTION"],
    ["23", "LeadDuplicateConversionService_Test", "Copado Integration", "System.AssertException"],
    ["24", "LeadDuplicateMatchingService_Test", "Copado Integration", "System.AssertException"],
    ["25", "LightningLoginFormControllerTest", "Amit Phadke", "System.AssertException"],
    ["26", "LightningSelfRegisterControllerTest", "Amit Phadke", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["27", "MemberPlanService_Test", "Copado Integration", "System.DmlException / ConvertLead failed; System.DmlException / FIELD_CUSTOM_VALIDATION (Lead Converted status)"],
    ["28", "ObjectTerritory2AService_Test", "Copado Integration", "System.AssertException; System.DmlException / INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY; System.DmlException / LIMIT_EXCEEDED (territory models)"],
    ["29", "OpportunityService_Test", "Copado Integration", "System.AssertException; System.DmlException / FIELD_CUSTOM_VALIDATION (Lead Converted status)"],
    ["30", "OrgSync_ACRService_Test", "Ramesh Kumar", "System.AssertException; System.DmlException / INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY"],
    ["31", "OrgSync_ContactPointObjectService_Test", "Ramesh Kumar", "System.AssertException; System.DmlException / FIELD_INTEGRITY_EXCEPTION"],
    ["32", "OrgSync_HandleHPFInsertion_Test", "Copado Integration", "System.AssertException"],
    ["33", "OrgSync_PatientDelegateService_Test", "Ramesh Kumar", "System.AssertException"],
    ["34", "OrgSync_PatientProviderCCR_Test", "Copado Integration", "System.AssertException"],
    ["35", "OrgSync_PatientProviderRelation_Test", "Copado Integration", "System.AssertException"],
    ["36", "OrgSync_PatientService_Test", "Ramesh Kumar", "System.AssertException"],
    ["37", "OrgSync_PatientStagingTrigger_Test", "Ramesh Kumar", "System.AssertException; System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code); System.DmlException / FIELD_INTEGRITY_EXCEPTION; System.DmlException / INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY"],
    ["38", "OrgSync_ProviderPracticeRelation_Test", "Copado Integration", "Unknown"],
    ["39", "OrgSync_SyncPhysicianStageService_Test", "Copado Integration", "System.AssertException"],
    ["40", "PatientLeadConversionService_Test", "Copado Integration", "System.AssertException; System.DmlException / ConvertLead failed"],
    ["41", "PatientLeadConversion_FunctionalTest", "Copado Integration", "System.DmlException / UNABLE_TO_LOCK_ROW"],
    ["42", "PortalTrainingController_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["43", "ProviderPracticeLeadMatchingService_Test", "Copado Integration", "System.DmlException / FIELD_INTEGRITY_EXCEPTION"],
    ["44", "ProviderPracticeLeadService_Test", "Copado Integration", "System.AssertException; System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code); System.DmlException / INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY; System.DmlException / INVALID_OPERATION; System.DmlException / STRING_TOO_LONG"],
    ["45", "ProviderRelationshipService_Test", "Copado Integration", "System.DmlException / ConvertLead failed; System.DmlException / FIELD_CUSTOM_VALIDATION (Lead Converted status); System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["46", "ReimbursementControllerTest", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code); System.DmlException / INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST"],
    ["47", "SendtoAspnServiceHelper_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION_EXCEPTION"],
    ["48", "SendtoAspnService_Test", "Copado Integration", "System.DmlException / CANNOT_EXECUTE_FLOW_TRIGGER; System.DmlException / FIELD_CUSTOM_VALIDATION_EXCEPTION; System.DmlException / FIELD_INTEGRITY_EXCEPTION"],
    ["49", "TakeExamCmpController_FunctionalTest", "Copado Integration", "Unknown"],
    ["50", "TaskGenerationService_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["51", "TerritoryAliasAccountBatch_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["52", "TerritoryAliasService_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["53", "TerritoryAliasSyncBatch_Test", "Copado Integration", "System.AssertException; System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["54", "TerritoryAliasSyncScheduler_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["55", "TerritoryAssignmentService_Test", "Copado Integration", "System.AssertException; System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code); System.DmlException / LIMIT_EXCEEDED (territory models)"],
    ["56", "TerritoryHierarchyService_FunctionalTest", "Copado Integration", "System.DmlException / INVALID_CROSS_REFERENCE_KEY"],
    ["57", "TerritoryRuleServiceHandler_Test", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code)"],
    ["58", "TrainerAssessmentHandlerTest", "Copado Integration", "System.AssertException"],
    ["59", "TrainingAssignmentHandler_Test", "Copado Integration", "System.DmlException / DUPLICATES_DETECTED"],
    ["60", "TrainingService_FunctionalTest", "Copado Integration", "System.AssertException; System.DmlException / CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY; System.DmlException / ConvertLead failed; System.DmlException / FIELD_CUSTOM_VALIDATION (Lead Converted status)"],
    ["61", "TrainingTaskCreationHandler_FuncTest", "Copado Integration", "System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code); System.DmlException / FIELD_INTEGRITY_EXCEPTION"],
    ["62", "TrainingTrigger_Test", "Copado Integration", "System.AssertException; System.DmlException / FIELD_CUSTOM_VALIDATION (Zip/Postal Code); System.DmlException / FIELD_CUSTOM_VALIDATION_EXCEPTION; System.DmlException / LIMIT_EXCEEDED (territory models)"],
    ["63", "Utility_Test", "Copado Integration", "System.DmlException / CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY"],
]

ERROR_SUMMARY = [
    ["Error Type", "Count"],
    ["FIELD_CUSTOM_VALIDATION (Zip/Postal Code)", "26 classes"],
    ["System.AssertException", "24 classes"],
    ["ConvertLead failed", "9 classes"],
    ["FIELD_CUSTOM_VALIDATION (Lead Converted status)", "6 classes"],
    ["LIMIT_EXCEEDED (territory models)", "4 classes"],
    ["UNABLE_TO_LOCK_ROW", "3 classes"],
    ["FIELD_INTEGRITY_EXCEPTION", "5 classes"],
    ["DUPLICATES_DETECTED", "3 classes"],
    ["CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY", "3 classes"],
    ["INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY", "4 classes"],
    ["DELETE_FAILED (contact point consents)", "1 class"],
    ["CANNOT_EXECUTE_FLOW_TRIGGER", "1 class"],
    ["APEX_DATA_ACCESS_RESTRICTION", "1 class"],
    ["INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST", "1 class"],
    ["INVALID_OPERATION", "1 class"],
    ["STRING_TOO_LONG", "1 class"],
    ["INVALID_CROSS_REFERENCE_KEY", "1 class"],
]


def main():
    out_path = os.path.join(os.path.dirname(__file__), "test-failures-consolidated.pdf")
    doc = SimpleDocTemplate(out_path, pagesize=landscape(A4), 
                          rightMargin=30, leftMargin=30, topMargin=30, bottomMargin=30)
    
    story = []
    styles = getSampleStyleSheet()
    
    # Title
    title_style = ParagraphStyle('CustomTitle', parent=styles['Heading1'], fontSize=16, textColor=colors.HexColor('#1a1a1a'), spaceAfter=12)
    story.append(Paragraph("Consolidated Test Failures Report", title_style))
    story.append(Paragraph("Unique Classes and Error Types", styles['Heading2']))
    story.append(Spacer(1, 0.1*inch))
    
    # Metadata section
    meta_style = ParagraphStyle('Meta', parent=styles['Normal'], fontSize=9, textColor=colors.grey)
    story.append(Paragraph(f"<b>Created By:</b> {CREATED_BY}", styles['Normal']))
    story.append(Paragraph(f"<b>Date:</b> {DATE}", styles['Normal']))
    story.append(Spacer(1, 0.1*inch))
    
    # Org Details
    story.append(Paragraph("<b>Org Details:</b>", styles['Normal']))
    for key, value in org_details.items():
        story.append(Paragraph(f"&nbsp;&nbsp;&nbsp;&nbsp;<b>{key}:</b> {value}", styles['Normal']))
    story.append(Spacer(1, 0.15*inch))
    
    # Source info
    story.append(Paragraph("<i>Source: testresults2.txt | Authors from metadata/org-details/apexclass.json</i>", meta_style))
    story.append(Spacer(1, 0.2*inch))
    
    # Summary by Class table
    story.append(Paragraph(f"<b>Summary by Class</b> (63 unique test classes with failures)", styles['Heading3']))
    story.append(Spacer(1, 0.1*inch))
    
    # Wrap long text in cells
    wrapped_data = []
    for row in TABLE_DATA:
        wrapped_row = []
        for i, cell in enumerate(row):
            if i == 3:  # Error types column - wrap text
                wrapped_row.append(Paragraph(cell, ParagraphStyle('CellText', parent=styles['Normal'], fontSize=7)))
            elif i == 1:  # Class name
                wrapped_row.append(Paragraph(cell, ParagraphStyle('CellText', parent=styles['Normal'], fontSize=7)))
            else:
                wrapped_row.append(cell)
        wrapped_data.append(wrapped_row)
    
    t = Table(wrapped_data, colWidths=[0.4*inch, 2.2*inch, 1.1*inch, 4.8*inch])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 8),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
        ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('FONTSIZE', (0, 1), (-1, -1), 7),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.lightgrey]),
    ]))
    story.append(t)
    story.append(PageBreak())
    
    # Error Types Summary
    story.append(Paragraph("<b>Error Types Summary</b>", styles['Heading3']))
    story.append(Spacer(1, 0.1*inch))
    
    t2 = Table(ERROR_SUMMARY, colWidths=[4.5*inch, 1.2*inch])
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('FONTSIZE', (0, 1), (-1, -1), 8),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.lightgrey]),
    ]))
    story.append(t2)
    
    doc.build(story)
    print(f"✓ PDF generated: {out_path}")
    print(f"  Pages: 2")
    print(f"  Format: Landscape A4")
    print(f"  Classes: 63")
    print(f"  Error Types: 17")


if __name__ == "__main__":
    main()
