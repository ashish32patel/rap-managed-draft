@EndUserText.label: 'Travel Projection View for Draft RefScen'
@AccessControl.authorizationCheck: #NOT_REQUIRED

@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['TravelID']
define root view entity ZAKP_C_TRAVEL_A_D
  provider contract transactional_query
  as projection on ZAKP_R_TRAVEL_D

{
  key TravelUUID,

      @Search.defaultSearchElement: true
      TravelID,

      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['AgencyName']
      @Consumption.valueHelpDefinition: [{ entity : {name: '/DMO/I_Agency_StdVH', element: 'AgencyID'  }, useForValidation: true }]
      AgencyID,
      _Agency.Name       as AgencyName,

      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['CustomerName']
      @Consumption.valueHelpDefinition: [{entity: {name: '/DMO/I_Customer_StdVH', element: 'CustomerID' }, useForValidation: true}]
      CustomerID,
      _Customer.LastName as CustomerName,

      BeginDate,

      EndDate,

      BookingFee,

      TotalPrice,

      @Consumption.valueHelpDefinition: [{entity: {name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
      CurrencyCode,

      Description,
      
      @ObjectModel.text.element: ['OverallStatusText']
      @Consumption.valueHelpDefinition: [{ entity: {name: '/DMO/I_Overall_Status_VH', element: 'OverallStatus' } }]      
      OverallStatus,
      _OverallStatus._Text.Text as OverallStatusText : localized, 
      

      LocalLastChangedAt,
      /* Associations */
      _Agency,
      _Booking : redirected to composition child ZAKP_C_BOOKING_A_D,
      _Currency,
      _OverallStatus, 
      _Customer
}
