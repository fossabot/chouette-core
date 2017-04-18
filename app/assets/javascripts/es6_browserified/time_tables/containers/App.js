var React = require('react')
var connect = require('react-redux').connect
var Component = require('react').Component
var actions = require('../actions')
var Metas = require('./Metas')
var Timetable = require('./Timetable')
var Navigate = require('./Navigate')

class App extends Component {
  componentDidMount(){
    this.props.onLoadFirstPage()
  }

  render(){
    return(
      <div>
        <Metas />
        <Navigate />
        <Timetable />
      </div>
    )
  }
}

const mapDispatchToProps = (dispatch) => {
  return {
    onLoadFirstPage: () =>{
      dispatch(actions.fetchingApi())
      actions.fetchTimeTables(dispatch)
    }
  }
}

const timeTableApp = connect(null, mapDispatchToProps)(App)

module.exports = timeTableApp
