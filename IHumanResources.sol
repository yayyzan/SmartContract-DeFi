// SPDX - License - Identifier : GPL -3.0
pragma solidity ^0.8.24;

/// @notice This interface defines the functions that the HumanResources contract must implement
/// The contract must be able to register employees , terminate them , and allowemployees to withdraw their salary
/// The contract will be funded using only USDC but will pay the employees in USDC or ETH

interface IHumanResources {
    
    /// @notice This error is raised if a user tries to call a function they are notauthorized to call
    error NotAuthorized ();


    /// @notice This error is raised if a user tries to register an employee that isalready registered
    error EmployeeAlreadyRegistered() ;


    /// @notice This error is raised if a user tries to terminate an employee that isnot registered
    error EmployeeNotRegistered() ;


    /// @notice This event is emitted when an employee is registered
    event EmployeeRegistered ( address indexed employee , uint256 weeklyUsdSalary );


    /// @notice This event is emitted when an employee is terminated
    event EmployeeTerminated ( address indexed employee );


    /// @notice This event is emitted when an employee withdraws their salary
    /// @param amount must be the amount in the currency the employee prefers ( USDC orETH ) scaled correctly
    event SalaryWithdrawn ( address indexed employee , bool isEth , uint256 amount );


    /// @notice This event is emitted when an employee switches the currency in whichthey receive the salary
    event CurrencySwitched ( address indexed employee , bool isEth );


    /// HR manager functions
    /// Only the address returned by the ‘hrManager ‘ below is able to call thesefunctions
    /// If anyone else tries to call them , the transaction must revert with the ‘NotAuthorized ‘ error above


    /// Registers an employee in the HR system
    /// @param employee address of the employee
    /// @param weeklyUsdSalary salary of the employee in USD scaled with 18 decimals
    function registerEmployee (
        address employee ,
        uint256 weeklyUsdSalary
    ) external ;


    /// Terminates the contract of a given an employee .
    /// The salary of the employee will stop being accumulated .
    /// @param employee address of the employee
    function terminateEmployee ( address employee ) external ;


    /// Employee functions
    /// These are only be callabale by employees 6
    /// If anyone else tries to call them , the transaction shall revert with the ‘NotAuthorized ‘ error above
    /// Only the ‘withdrawSalary ‘ can be called by non - active (i.e. terminated) employees


    /// Withdraws the salary of the employee
    /// This sends either USDC or ETH to the employee , depending on the employee ’spreference
    /// The salary accumulates with time ( regardless of nights , weekends , and othernon working hours ) according to the employee weekly salary
    /// This means that after 2 days , the employee will be able to withdraw 2/7 th ofhis weekly salary
    function withdrawSalary () external ;


    /// Switches the currency in which the employee receives the salary
    /// By default , the salary is paid in USDC
    /// If the employee calls this function , the salary will be paid in ETH
    /// If he calls it again , the salary will be paid in USDC again
    /// When the salary is paid in ETH , the contract will swap the amount to be paidfrom USDC to ETH
    /// When this function is called , the current accumulated salary should bewithdrawn automatically ( emitting the ‘SalaryWithdrawn ‘ event )
    function switchCurrency () external ;


    // Views


    /// Returns the salary available for withdrawal for a given employee
    /// This returns the amount in the currency the employee prefers ( USDC or ETH )
    /// The amount must be scaled with the correct number of decimals for the currency
    /// @param employee the address of the employee
    function salaryAvailable ( address employee ) external view returns ( uint256 );


    /// Returns the address of the HR manager
    function hrManager () external view returns ( address );


    /// Returns the number of active employees registered in the HR system
    function getActiveEmployeeCount () external view returns ( uint256 );


    /// Returns information about an employee
    /// If the employee does not exist , the function does not revert but all valuesreturned must be 0
    /// @param employee the address of the employee
    /// @return weeklyUsdSalary the weekly salary of the employee in USD , scaled with18 decimals
    /// @return employedSince the timestamp at which the employee was registered
    /// @return terminatedAt the timestamp at which the employee was terminated (or 0 if the employee is still active )
    function getEmployeeInfo (
        address employee
    )
        external
        view
        returns (
            uint256 weeklyUsdSalary ,
            uint256 employedSince ,
            uint256 terminatedAt
     );
}