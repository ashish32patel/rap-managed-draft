CLASS zcl_akp_load_draft_testdata DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_akp_load_draft_testdata IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DELETE FROM zakp_a_travel_d.
    DELETE FROM zakp_a_booking_d.
    DELETE FROM zakp_a_bksuppl_d.

    INSERT zakp_a_travel_d
    FROM  ( SELECT * FROM /dmo/a_travel_d  ).

    INSERT zakp_a_booking_d
    FROM  ( SELECT * FROM /dmo/a_booking_d  ).

    INSERT zakp_a_bksuppl_d
    FROM  ( SELECT * FROM /dmo/a_bksuppl_d ).

    out->write( `Data loaded successfully in tables` ).

    COMMIT WORK.


  ENDMETHOD.
ENDCLASS.
