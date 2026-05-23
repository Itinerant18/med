# Task Plan: Medical Visit Form Field Customizations

## Goal
Implement layout and field changes for Log Visit, Add External Visit, and New External Visit screens as per the user's specific request.

## Current Phase
Phase 3: Implementation

## Phases

### Phase 1: Requirements & Discovery
- [x] Understand user intent and list required changes
- [x] Identify files corresponding to Log Visit, Add External Visit, and New External Visit
- [x] Map the exact changes for each screen
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Define technical approach for form modifications (state management, field changes, controller/form state)
- [x] Update findings.md with precise code locations and detailed diff plans
- **Status:** complete (Awaiting User Approval)

### Phase 3: Implementation
- [ ] Modify "Log Visit" sheet/page: add Post Op Referred To, remove Vitals section, remove Prescriptions field.
- [ ] Modify "Add External Visit" page: add District Dropdown, Type Of Doctor.
- [ ] Modify "New External Visit" page: remove doctors data except Hospital/Clinic and How Many Time Visited; add No of Patient Received and Work Pending; remove Prescriptions, Diagnosis, and Chief complaint.
- **Status:** pending

### Phase 4: Testing & Verification
- [ ] Perform analysis options check (static analysis / linter) to ensure no syntax/compilation issues
- [ ] Ensure all form widgets build successfully
- **Status:** pending

### Phase 5: Delivery
- [ ] Document final walkthrough in walkthrough.md
- [ ] Update progress.md with session summary
- **Status:** pending

## Key Questions
1. Where are the database models or states mapped to these forms, and do we need to modify them as well, or is this a purely UI-centric field layout change?
2. Are "Add External Visit" and "New External Visit" two different forms/sheets, or are they related (e.g. part of the same folder or file)?
3. What dropdown values should be in "District" and "Type Of Doctor"?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use planning-with-files | User requested /planning-with-files explicitly |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| None yet | | |

## Notes
- Update phase status as you progress: pending → in_progress → complete
- Re-read this plan before major decisions (attention manipulation)
- Log ALL errors - they help avoid repetition
