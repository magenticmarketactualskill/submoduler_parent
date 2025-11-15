# Requirements Document - Parent Test Command

## Introduction

This document specifies the requirements for the Submoduler Parent test command, which runs tests across the parent repository and all child submodules.

## Glossary

- **Submoduler Parent**: A command-line tool for managing operations within a SubmoduleParent repository
- **Test Command**: A command that executes test suites
- **SubmoduleParent**: A git repository with .gitmodules and .submoduler.ini file where [default] submodule_parent=true
- **SubmoduleChild**: A git repository with .gitmodules and .submoduler.ini file where [default] submodule_child=true
- **Test Suite**: A collection of automated tests for a repository
- **Test Failure**: A test that does not pass, indicating a problem

## Requirements

### Requirement 1: Run Parent Tests

**User Story:** As a developer, I want to run parent repository tests, so that I can verify parent functionality

#### Acceptance Criteria

1. WHEN the developer runs "bin/submoduler_parent.rb test", THE Submoduler Parent SHALL execute tests in the parent repository
2. THE Submoduler Parent SHALL use the standard Ruby test framework (minitest or rspec)
3. THE Submoduler Parent SHALL display test output in real-time
4. THE Submoduler Parent SHALL report the number of tests run and passed
5. IF parent tests fail, THEN THE Submoduler Parent SHALL display failure details

### Requirement 2: Run Child Submodule Tests

**User Story:** As a developer, I want to run tests in all child submodules, so that I can verify the entire system

#### Acceptance Criteria

1. THE Submoduler Parent SHALL discover all child submodules from .gitmodules
2. THE Submoduler Parent SHALL execute tests in each child submodule
3. WHILE require_tests_pass=true in a child's .submoduler.ini, THE Submoduler Parent SHALL mark test failures as blocking
4. WHILE require_tests_pass=false in a child's .submoduler.ini, THE Submoduler Parent SHALL mark test failures as warnings
5. THE Submoduler Parent SHALL display a summary of test results for all submodules

### Requirement 3: Handle Test Execution

**User Story:** As a developer, I want flexible test execution options, so that I can control which tests run

#### Acceptance Criteria

1. THE Submoduler Parent SHALL support a --parent-only flag to run only parent tests
2. THE Submoduler Parent SHALL support a --children-only flag to run only child tests
3. THE Submoduler Parent SHALL support a --submodule flag to run tests for a specific child
4. WHEN no flags are provided, THE Submoduler Parent SHALL run all tests
5. THE Submoduler Parent SHALL skip submodules that have no test directory

### Requirement 4: Report Test Results

**User Story:** As a developer, I want clear test result reporting, so that I can identify failures quickly

#### Acceptance Criteria

1. THE Submoduler Parent SHALL use visual indicators (✓, ✗) for pass and fail status
2. THE Submoduler Parent SHALL display test execution time for each repository
3. THE Submoduler Parent SHALL group output by parent and children sections
4. WHEN all tests pass, THE Submoduler Parent SHALL display a success message and exit with status code 0
5. IF any required tests fail, THEN THE Submoduler Parent SHALL exit with a non-zero status code
