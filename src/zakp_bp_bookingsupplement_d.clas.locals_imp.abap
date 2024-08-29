CLASS lhc_bookingsupplement DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR BookingSupplement~calculateTotalPrice.

ENDCLASS.

CLASS lhc_bookingsupplement IMPLEMENTATION.

  METHOD calculateTotalPrice.
    READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY BookingSupplement BY \_Travel
        FIELDS ( TravelUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_travels).


    MODIFY ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        EXECUTE reCalcTotalPrice
        FROM CORRESPONDING #( lt_travels )
        FAILED DATA(lt_failed).
  ENDMETHOD.

ENDCLASS.

*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
