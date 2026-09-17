SELECT *

FROM INFORMATION_SCHEMA.TABLES;

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'healthcare_dwh_s2')

    CREATE DATABASE healthcare_dwh_s2;

USE healthcare_dwh_s2;

-- Schemas for the four data warehouse layers

SELECT *

FROM sys.schemas;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')

    EXEC('CREATE SCHEMA staging');

GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')

    EXEC('CREATE SCHEMA bronze');

GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')

    EXEC('CREATE SCHEMA silver');

GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')

    EXEC('CREATE SCHEMA gold');

GO

--Table raw_encounters
 
CREATE TABLE staging.raw_encounters (
    patient_id NVARCHAR(255),
    birth_year NVARCHAR(255),
    age NVARCHAR(255),
    sex NVARCHAR(255),
    race_ethnicity NVARCHAR(255),
    state NVARCHAR(255),
    encounter_id NVARCHAR(255),
    icd10_code NVARCHAR(255),
    diagnosis_display NVARCHAR(255),
    diagnosis_category NVARCHAR(255),
    severity_index NVARCHAR(255),
    comorbidity_count NVARCHAR(255),
    has_diabetes NVARCHAR(255),
    has_hypertension NVARCHAR(255),
    has_chf NVARCHAR(255),
    sbp_mmhg NVARCHAR(255),
    dbp_mmhg NVARCHAR(255),
    heart_rate_bpm NVARCHAR(255),
    spo2_pct NVARCHAR(255),
    temperature_f NVARCHAR(255),
    bmi NVARCHAR(255),
    respiratory_rate NVARCHAR(255),
    hba1c_pct NVARCHAR(255),
    glucose_mg_dl NVARCHAR(255),
    creatinine_mg_dl NVARCHAR(255),
    wbc_10e3_ul NVARCHAR(255),
    nt_probnp_pg_ml NVARCHAR(255),
    medication_adherence_pdc NVARCHAR(255),
    readmission_30d_flag NVARCHAR(255),
    triage_timestamp NVARCHAR(255),
    admit_timestamp NVARCHAR(255),
    bed_request_time NVARCHAR(255),
    bed_assign_time NVARCHAR(255),
    unit_assigned NVARCHAR(255),
    bed_occupancy_pct NVARCHAR(255),
    cpt_code NVARCHAR(255),
    procedure_display NVARCHAR(255),
    or_start NVARCHAR(255),
    or_end NVARCHAR(255),
    actual_or_minutes NVARCHAR(255),
    or_turnover_minutes NVARCHAR(255),
    los_days NVARCHAR(255),
    discharge_timestamp NVARCHAR(255),
    safety_incident_flag NVARCHAR(255),
    incident_type NVARCHAR(255),
    incident_severity NVARCHAR(255),
    claim_id NVARCHAR(255),
    payer NVARCHAR(255),
    npi_billing NVARCHAR(255),
    drg_weight NVARCHAR(255),
    submitted_charge_usd NVARCHAR(255),
    allowed_amount_usd NVARCHAR(255),
    patient_responsibility_usd NVARCHAR(255),
    fraud_upcoding_flag NVARCHAR(255),
    fraud_duplicate_flag NVARCHAR(255),
    fraud_unbundling_flag NVARCHAR(255),
    nurse_emp_id NVARCHAR(255),
    nurse_role NVARCHAR(255),
    nurse_unit NVARCHAR(255),
    nurse_tenure_years NVARCHAR(255),
    nurse_fte NVARCHAR(255),
    surgeon_emp_id NVARCHAR(255),
    surgeon_specialty NVARCHAR(255),
    shift_hours NVARCHAR(255),
    patients_per_nurse_ratio NVARCHAR(255),
    overtime_hours NVARCHAR(255),
    burnout_exhaustion_mbi NVARCHAR(255),
    burnout_cynicism_mbi NVARCHAR(255),
    burnout_personal_accomplishment_mbi NVARCHAR(255),
    turnover_risk_index NVARCHAR(255),
    cahps_nurse_communication NVARCHAR(255),
    cahps_doctor_communication NVARCHAR(255),
    cahps_responsiveness NVARCHAR(255),
    cahps_pain_management NVARCHAR(255),
    cahps_discharge_info NVARCHAR(255),
    cahps_care_transition NVARCHAR(255),
    cahps_cleanliness NVARCHAR(255),
    cahps_quietness NVARCHAR(255),
    surgical_kit_id NVARCHAR(255),
    kit_name NVARCHAR(255),
    kit_unit_cost_usd NVARCHAR(255),
    kit_current_stock NVARCHAR(255),
    kit_reorder_point NVARCHAR(255),
    kit_lead_time_days NVARCHAR(255),
    kit_expiration_date NVARCHAR(255),
    stockout_risk_flag NVARCHAR(255),
    weekly_procedure_volume NVARCHAR(255),
    projected_demand_4wk NVARCHAR(255),
    days_of_supply NVARCHAR(255),
    hedis_hba1c_tested NVARCHAR(255),
    hedis_hba1c_poor_control NVARCHAR(255),
    pdsa_cycle_id NVARCHAR(255),
    himss_emram_stage NVARCHAR(255)
);
SELECT *
FROM staging.raw_encounters;
-- Now, we are going to start reading the data from the file into the stagging table.
-- Here is our decision to build the staging area as full loading area with truncating
-- all the data inside the table first then we start loading the new data into it
-- It is a full truncate loading data
TRUNCATE TABLE staging.raw_encounters;
 
BULK INSERT staging.raw_encounters
FROM 'C:\Users\Active\Downloads\encounters_1m.csv'
WITH (
    FIRSTROW = 2,              -- skip the header row
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FORMAT = 'CSV',
    FIELDQUOTE = '"', -- Properly read the comma inside the double quotations
    CODEPAGE = '65001',        -- UTF-8
    MAXERRORS = 0,
    ERRORFILE = 'C:\Users\Active\Downloads\raw_encounters_err.log'
);
 
select * from staging.raw_encounters;