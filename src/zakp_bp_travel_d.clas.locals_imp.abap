CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Travel RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR travel RESULT result.


    METHODS recalctotalprice FOR MODIFY
      IMPORTING keys FOR ACTION travel~recalctotalprice.


    METHODS accepttravel FOR MODIFY
      IMPORTING keys FOR ACTION travel~accepttravel RESULT result.

    METHODS deductdiscount FOR MODIFY
      IMPORTING keys FOR ACTION travel~deductdiscount RESULT result.

    METHODS rejecttravel FOR MODIFY
      IMPORTING keys FOR ACTION travel~rejecttravel RESULT result.
    METHODS calculatetotalprice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR travel~calculatetotalprice.



ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        FIELDS ( OverallStatus )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_travels)
        FAILED DATA(lt_failed).

    result = VALUE #( FOR travel IN lt_travels (
                            %tky = travel-%tky
                            %action-acceptTravel = COND #( WHEN travel-OverallStatus EQ 'A' THEN if_abap_behv=>fc-o-disabled
                                                           ELSE if_abap_behv=>fc-o-enabled )
                            %action-rejectTravel = COND #( WHEN travel-OverallStatus EQ 'X' THEN if_abap_behv=>fc-o-disabled
                                                           ELSE if_abap_behv=>fc-o-enabled )

                     ) ).


  ENDMETHOD.



  METHOD reCalcTotalPrice.
    TYPES: BEGIN OF ty_amount_per_currencycode,
             amount        TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_amount_per_currencycode.
    DATA: amount_per_currencycode TYPE STANDARD TABLE OF ty_amount_per_currencycode.

    READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
            FIELDS ( BookingFee CurrencyCode )
            WITH CORRESPONDING #( keys )
            RESULT DATA(travels).

    DELETE travels WHERE CurrencyCode IS INITIAL.

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
      amount_per_currencycode = VALUE #( ( amount = <travel>-BookingFee currency_code = <travel>-CurrencyCode ) ).

      READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel BY \_Booking
        FIELDS ( FlightPrice CurrencyCode )
        WITH VALUE #( ( %tky = <travel>-%tky ) )
        RESULT DATA(bookings).

*      LOOP AT bookings ASSIGNING FIELD-SYMBOL(<booking>) WHERE CurrencyCode IS NOT INITIAL.
*        amount_per_currencycode = VALUE #( BASE amount_per_currencycode ( amount = <booking>-FlightPrice currency_code = <booking>-CurrencyCode ) ).
*      ENDLOOP.

      amount_per_currencycode = VALUE #( BASE amount_per_currencycode
                                         FOR booking IN bookings WHERE ( CurrencyCode IS NOT INITIAL )
                                            ( amount = booking-FlightPrice currency_code = booking-CurrencyCode )
                                       ).

      READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
          ENTITY Booking BY \_BookingSupplement
          FIELDS ( BookSupplPrice CurrencyCode )
          WITH VALUE #( FOR booking IN bookings ( %tky = booking-%tky ) )
          RESULT DATA(bookingsupplements).

      amount_per_currencycode = VALUE #( BASE amount_per_currencycode
                                            FOR booksuppl IN bookingsupplements
                                                ( amount = booksuppl-BookSupplPrice currency_code = booksuppl-CurrencyCode )
                                       ).

      CLEAR <travel>-TotalPrice.
      LOOP AT amount_per_currencycode ASSIGNING FIELD-SYMBOL(<single_amount_per_currcode>).
        IF <single_amount_per_currcode>-currency_code = <travel>-CurrencyCode.
          <travel>-TotalPrice += <single_amount_per_currcode>-amount.

        ELSE.
          /dmo/cl_flight_amdp=>convert_currency(
            EXPORTING
              iv_amount               = <single_amount_per_currcode>-amount
              iv_currency_code_source = <single_amount_per_currcode>-currency_code
              iv_currency_code_target = <travel>-CurrencyCode
              iv_exchange_rate_date   = cl_abap_context_info=>get_system_date( )
            IMPORTING
              ev_amount               = DATA(converted_amt)
          ).

          <travel>-TotalPrice += converted_amt.
        ENDIF.

      ENDLOOP.
    ENDLOOP.

    " write back the modified total_price of travels
    MODIFY ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        UPDATE FIELDS ( TotalPrice )
        WITH CORRESPONDING #( travels ).

  ENDMETHOD.

  METHOD acceptTravel.
    MODIFY ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'A' ) )
        FAILED DATA(lt_failed)
        REPORTED DATA(lt_reported)
        MAPPED DATA(lt_mapped).

    READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        ALL FIELDS
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_travels)
        FAILED DATA(lt_failed1)
        REPORTED DATA(lt_reported1).

    result = VALUE #( FOR travel IN lt_travels
                            (
                                %tky = travel-%tky
                                %param = travel
                            ) ).

  ENDMETHOD.

  METHOD deductDiscount.

    DATA lt_upd_travel TYPE TABLE FOR UPDATE zakp_r_travel_d\\Travel.

    DATA(lt_keys) = keys.

    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<fs_key>) WHERE %param-discount_percent IS INITIAL
                                                     OR %param-discount_percent LT 0
                                                     OR %param-discount_percent GT 100.

      failed-travel = VALUE #( BASE failed-travel ( %tky = <fs_key>-%tky ) ).
      reported-travel = VALUE #( BASE reported-travel (
                                          %tky = <fs_key>-%tky
                                          %msg = NEW /dmo/cm_flight_messages(
                                                         textid = /dmo/cm_flight_messages=>discount_invalid
                                                         severity = if_abap_behv_message=>severity-error )
                                          %element-bookingfee = if_abap_behv=>mk-on
                                          %action-deductDiscount = if_abap_behv=>mk-on
      ) ).

      DELETE lt_keys.
    ENDLOOP.

    READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        FIELDS ( BookingFee )
        WITH CORRESPONDING #( lt_keys )
        RESULT DATA(lt_travels).

    LOOP AT lt_travels ASSIGNING FIELD-SYMBOL(<travel>).
      DATA(lv_discount) = lt_keys[ KEY id %tky = <travel>-%tky ]-%param-discount_percent.
      DATA(disc) = CONV decfloat16( lv_discount / 100 ).

      lt_upd_travel = VALUE #( BASE lt_upd_travel (
                                    %tky = <travel>-%tky
                                    BookingFee = <travel>-BookingFee - <travel>-BookingFee * disc
                                   ) ).
    ENDLOOP.


    MODIFY ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        UPDATE FIELDS ( BookingFee )
        WITH lt_upd_travel
        REPORTED DATA(lt_upd_reported)
        FAILED DATA(lt_upd_failed).

    READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
         ENTITY Travel
         ALL FIELDS WITH CORRESPONDING #( lt_keys )
         RESULT DATA(lt_modified_travel).


    result = VALUE #( FOR travel IN lt_modified_travel ( %tky = travel-%tky %param = travel  ) ).



  ENDMETHOD.

  METHOD rejectTravel.
    MODIFY ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'X' ) )
        FAILED DATA(lt_failed)
        REPORTED DATA(lt_reported)
        MAPPED DATA(lt_mapped).

    READ ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        ALL FIELDS
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_travels)
        FAILED DATA(lt_failed1)
        REPORTED DATA(lt_reported1).

    result = VALUE #( FOR travel IN lt_travels
                            (
                                %tky = travel-%tky
                                %param = travel
                            ) ).
  ENDMETHOD.



































  METHOD calculateTotalPrice.
    MODIFY ENTITIES OF zakp_r_travel_d IN LOCAL MODE
        ENTITY Travel
        EXECUTE reCalcTotalPrice
        FROM CORRESPONDING #( keys )
        FAILED DATA(lt_failed)
        REPORTED DATA(lt_reported).
  ENDMETHOD.

ENDCLASS.
