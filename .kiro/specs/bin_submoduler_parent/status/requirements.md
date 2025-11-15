# Requirements Document - Parent Status Command

## Introduction

This document specifies the requirements for the Submoduler Parent status command, which displays the git status of the parent repository and all child submodules.

## Glossary

- **Submoduler Parent**: A command-line tool for managing operations within a SubmoduleParent repository
- **Status Command**: A command that displays git status information
- **SubmoduleParent**: A git repository with .gitmodules and .submoduler.ini file where [default] submodule_parent=true
- **SubmoduleChild**: A git repository with .gitmodules and .submoduler.ini file where [default] submodule_child=true
- **Working Tree**: The current state of files in a git repository
- **Dirty Repository**: A repository with uncommitted changes

## Requirements

### Requirement 1: Display Parent Status

**User Story:** As a developer, I want to see the parent repository status, so that I know if there are uncommitted changes

#### Acceptance Criteria

1. WHEN the developer runs "bin/submoduler_parent.rb status", THE Submoduler Parent SHALL display the git status of the parent repository
2. THE Submoduler Parent SHALL indicate if the parent working tree is clean
3. THE Submoduler Parent SHALL list modified files in the parent repository
4. THE Submoduler Parent SHALL list untracked files in the parent repository
5. THE Submoduler Parent SHALL indicate if there are staged changes in the parent repository

### Requirement 2: Display Child Submodule Status

**User Story:** As a developer, I want to see all child submodule statuses, so that I can identify which submodules have changes

#### Acceptance Criteria

1. THE Submoduler Parent SHALL discover all child submodules from .gitmodules
2. THE Submoduler Parent SHALL display the git status for each child submodule
3. THE Submoduler Parent SHALL indicate if each child working tree is clean
4. THE Submoduler Parent SHALL list modified files in each child submodule
5. THE Submoduler Parent SHALL display a summary count of clean vs dirty submodules

### Requirement 3: Format Status Output

**User Story:** As a developer, I want clear, formatted status output, so that I can quickly understand the state of my repositories

#### Acceptance Criteria

1. THE Submoduler Parent SHALL use visual indicators (✓, ✗) for clean and dirty status
2. THE Submoduler Parent SHALL group output by parent and children sections
3. THE Submoduler Parent SHALL use indentation to show hierarchy
4. THE Submoduler Parent SHALL use color coding for different status types
5. WHEN all repositories are clean, THE Submoduler Parent SHALL display a success message

### Requirement 4: Handle Status Errors

**User Story:** As a developer, I want clear error messages for status failures, so that I can troubleshoot issues

#### Acceptance Criteria

1. IF git is not available, THEN THE Submoduler Parent SHALL display an error message
2. IF a submodule directory does not exist, THEN THE Submoduler Parent SHALL report the missing submodule
3. IF git status fails for any repository, THEN THE Submoduler Parent SHALL display the specific error
4. THE Submoduler Parent SHALL continue checking other submodules even if one fails
5. WHEN errors occur, THE Submoduler Parent SHALL exit with a non-zero status code
