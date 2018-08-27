import React from 'react'
import { NavLink as Link } from 'react-router-dom'
import WatchlistsPopup from './../../components/WatchlistPopup/WatchlistsPopup'
import './AssetsPageNavigation.css'

const MyListBtn = (
  <div className='projects-navigation-list__page-link'>Watchlists</div>
)

const AssetsPageNavigation = ({ isLoggedIn = false }) => {
  return (
    <div className='projects-navigation'>
      <div className='projects-navigation-list'>
        <Link
          activeClassName='projects-navigation-list__page-link--active'
          className='projects-navigation-list__page-link'
          to={'/assets/erc20'}
        >
          ERC20 Projects
        </Link>
        <Link
          activeClassName='projects-navigation-list__page-link--active'
          className='projects-navigation-list__page-link'
          to={'/assets/currencies'}
        >
          Currencies
        </Link>
        <Link
          activeClassName='projects-navigation-list__page-link--active'
          className='projects-navigation-list__page-link'
          to={'/ethereum-spent'}
        >
          Ethereum Spent Overview
        </Link>
        {isLoggedIn && (
          <WatchlistsPopup
            isNavigation
            isLoggedIn={isLoggedIn}
            trigger={MyListBtn}
          />
        )}
      </div>
    </div>
  )
}

export default AssetsPageNavigation