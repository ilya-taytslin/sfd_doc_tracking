create or replace trigger TRI_IVR_EFP_PROJECT
    after insert
    on VESSELS
    for each row
declare

    projectcd EFP_FORM_DATA.PROJECT_CODE%type;
    permit_project_ue EFP_FORM_DATA.UE%type;
    permit_project_de EFP_FORM_DATA.DE%type;
    doc_type EFP_FORM_DATA.DOCUMENT_TYPE%type;
    rsa_program EFP_FORM_DATA.RSA_PROGRAM%type;
    
    rsa_exists number(1); 
    vCount integer;
    v_NIVR_CALLER_exists number(1); 
    v_exemption_found number(1) := 0;
BEGIN
    vCount := 0;
    select 1 into v_exemption_found
    from exemption
    where document_id = :NEW.document_id and name in ( 'HailStart', 'HailEnd');
    EXCEPTION
        WHEN no_data_found
        THEN
            v_exemption_found := 0;
      
    IF (:NEW.permit IS NOT NULL) AND v_exemption_found = 1 
    THEN
      SELECT PROJECT_CODE, 
             NVL(SUBSTR(UE, 0, INSTR(UE, '@')-1), UE), 
             DE, DOCUMENT_TYPE, nvl(RSA_PROGRAM, 'NONE')
        INTO projectcd, permit_project_ue, permit_project_de, doc_type, rsa_program
        FROM EFP_FORM_DATA
        WHERE id_number = :NEW.document_id;

        IF doc_type = 'EFP' THEN

            IF rsa_program = 'NONE' THEN
                rsa_exists := 0;
            ELSE
                rsa_exists := 1;
            END IF;

            IF rsa_exists = 1 THEN
                select count(permit_projectid) into vCount from neroivr.NIVR_PERMIT_PROJECT 
                where caller_permitnbr = :new.permit and rsa_projectcd = projectcd;
                IF vCount = 0 THEN
                    INSERT INTO neroivr.NIVR_PERMIT_PROJECT 
                    (
                    CALLER_PERMITNBR,
                    PERMIT_PROJECTID,   
                    EFP_PROJECTCD,
                    RSA_PROJECTCD ,
                    PERMIT_PROJECT_UE , 
                    PERMIT_PROJECT_DE,   
                    DELETED_ON
                    )
                    values (
                        :NEW.permit
                        ,null
                        ,null
                        ,projectcd  -- RSA project code
                        ,permit_project_ue
                        ,permit_project_de
                        ,null
                        ) ;
                END IF;
            ELSE
                select count(permit_projectid) into vCount from neroivr.NIVR_PERMIT_PROJECT 
                where caller_permitnbr = :new.permit and efp_projectcd = projectcd;
                IF vCount = 0 THEN
                    SELECT count(*) as v_exists 
                    INTO v_NIVR_CALLER_exists
                    FROM NEROIVR.NIVR_CALLER C 
                    WHERE C.CALLER_PERMITNBR = :NEW.permit;

                    IF v_NIVR_CALLER_exists = 0 THEN
                        INSERT INTO NEROIVR.NIVR_CALLER (CALLER_PERMITNBR)
                        VALUES (:NEW.permit);
                    END IF;

                    IF projectcd IS NOT NULL THEN
                       --select NEROIVR.fn_insert_efp_project (projectcd) into vCount from dual;
                       vCount := NEROIVR.fn_insert_efp_project (projectcd); 
                    END IF;
                    INSERT INTO neroivr.NIVR_PERMIT_PROJECT 
                    (
                    CALLER_PERMITNBR,
                    PERMIT_PROJECTID,   
                    EFP_PROJECTCD,
                    RSA_PROJECTCD ,
                    PERMIT_PROJECT_UE , 
                    PERMIT_PROJECT_DE,   
                    DELETED_ON
                    )
                    values (
                        :NEW.permit
                        ,null
                        ,projectcd  -- EFP project code
                        ,null
                        ,permit_project_ue
                        ,permit_project_de
                        ,null) ;
                END IF;
            END IF;
        END IF;
    END IF;
END;