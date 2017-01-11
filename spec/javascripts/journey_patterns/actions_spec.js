var actions = require('es6_browserified/journey_patterns/actions')

const dispatch = function(){}
const currentPage = 1

describe('when receiveJourneyPatterns is triggered', () => {
  it('should create an action to pass json to reducer', () => {
    const json = undefined
    const expectedAction = {
      type: 'RECEIVE_JOURNEY_PATTERNS',
      json
    }
    expect(actions.receiveJourneyPatterns()).toEqual(expectedAction)
  })
})

describe('when landing on page', () => {
  it('should create an action to load the n first missions', () => {
    const expectedAction = {
      type: 'LOAD_FIRST_PAGE',
      dispatch
    }
    expect(actions.loadFirstPage(dispatch)).toEqual(expectedAction)
  })
})
describe('when previous navigation button is clicked', () => {
  it('should create an action to go to previous page', () => {
    const nextPage = false
    const pagination = {
      totalCount: 25,
      perPage: 12,
      page:1
    }
    const expectedAction = {
      type: 'GO_TO_PREVIOUS_PAGE',
      dispatch,
      pagination,
      nextPage
    }
    expect(actions.goToPreviousPage(dispatch, pagination)).toEqual(expectedAction)
  })
})
describe('when next navigation button is clicked', () => {
  it('should create an action to go to next page', () => {
    const nextPage = true
    const pagination = {
      totalCount: 25,
      perPage: 12,
      page:1
    }
    const expectedAction = {
      type: 'GO_TO_NEXT_PAGE',
      dispatch,
      pagination,
      nextPage
    }
    expect(actions.goToNextPage(dispatch, pagination)).toEqual(expectedAction)
  })
})
describe('when clicking on a journey pattern checkbox', () => {
  it('should create an action to update journey pattern stop points', () => {
    const event = {
      currentTarget: {
        id: '1'
      }
    }
    const index = 1
    const expectedAction = {
      type: 'UPDATE_CHECKBOX_VALUE',
      id: event.currentTarget.id,
      index,
    }
    expect(actions.updateCheckboxValue(event, index)).toEqual(expectedAction)
  })
})
describe('when clicking on next button', () => {
  it('should create an action to open a confirm modal', () => {
    const callback = function(){}
    const expectedAction = {
      type: 'OPEN_CONFIRM_MODAL',
      callback
    }
    expect(actions.openConfirmModal(callback)).toEqual(expectedAction)
  })
})
describe('when clicking on edit button', () => {
  it('should create an action to open a edit modal', () => {
    const index = 1
    const journeyPattern = {}
    const expectedAction = {
      type: 'EDIT_JOURNEYPATTERN_MODAL',
      index,
      journeyPattern,
    }
    expect(actions.openEditModal(index, journeyPattern)).toEqual(expectedAction)
  })
})
describe('when clicking on add button', () => {
  it('should create an action to open a create modal', () => {
    const expectedAction = {
      type: 'CREATE_JOURNEYPATTERN_MODAL',
    }
    expect(actions.openCreateModal()).toEqual(expectedAction)
  })
})
describe('when clicking on close button inside edit or add modal', () => {
  it('should create an action to close modal', () => {
    const expectedAction = {
      type: 'CLOSE_MODAL',
    }
    expect(actions.closeModal()).toEqual(expectedAction)
  })
})
describe('when clicking on a journey pattern delete button', () => {
  it('should create an action to delete journey pattern', () => {
    const index = 1
    const expectedAction = {
      type: 'DELETE_JOURNEYPATTERN',
      index
    }
    expect(actions.deleteJourneyPattern(index)).toEqual(expectedAction)
  })
})
describe('when clicking on validate button inside edit modal', () => {
  it('should create an action to save journey pattern modifications', () => {
    const index = 1
    const data = {}
    const expectedAction = {
      type: 'SAVE_MODAL',
      index,
      data
    }
    expect(actions.saveModal(index, data)).toEqual(expectedAction)
  })
})
describe('when clicking on validate button inside create modal', () => {
  it('should create an action to create a new journey pattern', () => {
    const data = {}
    const expectedAction = {
      type: 'ADD_JOURNEYPATTERN',
      data
    }
    expect(actions.addJourneyPattern(data)).toEqual(expectedAction)
  })
})
describe('when submitting new journeyPatterns', () => {
  it('should create an action to update pagination totalCount', () => {
    const diff = 1
    const expectedAction = {
      type: 'UPDATE_TOTAL_COUNT',
      diff
    }
    expect(actions.updateTotalCount(diff)).toEqual(expectedAction)
  })
})
