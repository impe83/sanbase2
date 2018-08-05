import Raven from 'raven-js'
import { Observable } from 'rxjs'
import { tap, zip, mergeMap, retryWhen, concat } from 'rxjs/operators'
import { projectBySlugGQL } from './../pages/Projects/allProjectsGQL'
import { AssetsListGQL } from './../components/AssetsListPopup/AssetsListGQL'
import {
  allProjectsGQL,
  allErc20ProjectsGQL,
  currenciesGQL
} from './../pages/Projects/allProjectsGQL'
import * as actions from './../actions/types'

const getTimeout = ({ minTimeout, maxTimeout, attempt }) =>
  Math.min(Math.random() * minTimeout * Math.pow(2, attempt), maxTimeout)

export const retry = (times = 3, fallback) => {
  return retryWhen(errors => {
    return errors.pipe(
      zip(Observable.range(1, 3), (_, i) => i),
      tap(time => console.log(`Retry to fetch ${time}`)),
      mergeMap(retryCount =>
        Observable.timer(
          getTimeout({
            minTimeout: 1000,
            maxTimeout: 10000,
            attempt: retryCount
          })
        )
      ),
      concat(Observable.throw(new Error('Retry limit exceeded!')))
    )
  }).catchError(() => Observable.of(fallback))
}

const fetchAssets$ = ({ type = 'all', client }) => {
  return Observable.of(type).switchMap(type =>
    client.query({ query: pickProjectsType(type).gql })
  )
}

const pickProjectsType = type => {
  switch (type) {
    case 'all':
      return {
        projects: 'allProjects',
        gql: allProjectsGQL
      }
    case 'currency':
      return {
        projects: 'allCurrencyProjects',
        gql: currenciesGQL
      }
    case 'erc20':
      return {
        projects: 'allErc20Projects',
        gql: allErc20ProjectsGQL
      }
    default:
      return {
        projects: 'allProjects',
        gql: allProjectsGQL
      }
  }
}

const mapDataToAssets = ({ type, data }) => {
  const { loading, error } = data
  const items = !data.error ? data.data[pickProjectsType(type).projects] : []
  const isEmpty = items && items.length === 0
  return {
    isLoading: loading,
    isEmpty,
    items,
    error
  }
}

export const fetchAssetsEpic = (action$, store, { client }) =>
  action$
    .ofType(actions.ASSETS_FETCH)
    .filter(({ payload }) => {
      return payload.type !== 'list'
    })
    .mergeMap(action => {
      const { type } = action.payload
      const startTime = Date.now()
      return fetchAssets$({ type, client })
        .delayWhen(() => Observable.timer(500 + startTime - Date.now()))
        .exhaustMap(data => {
          return Observable.of({
            type: actions.ASSETS_FETCH_SUCCESS,
            payload: mapDataToAssets({ type, data })
          })
        })

        .catch(error => {
          Raven.captureException(error)
          return Observable.of({
            type: actions.ASSETS_FETCH_FAILED,
            payload: error
          })
        })
    })

export const fetchAssetsFromListEpic = (action$, store, { client }) =>
  action$
    .ofType(actions.ASSETS_FETCH)
    .filter(({ payload }) => {
      return payload.type === 'list'
    })
    .mergeMap(({ payload }) => {
      return Observable.from(client.query({ query: AssetsListGQL })).concatMap(
        ({ data = {} }) => {
          const startTime = Date.now()
          const { fetchUserLists } = data
          const { listItems = [] } =
            fetchUserLists.find(item => item.id === payload.list.id) || {}
          const queries = listItems
            .map(asset => {
              return asset.project.slug
            })
            .map(slug => {
              return client.query({
                query: projectBySlugGQL,
                variables: { slug }
              })
            })

          if (listItems.length === 0) {
            return Observable.of({
              type: actions.ASSETS_FETCH_SUCCESS,
              payload: {
                items: [],
                isLoading: false,
                error: false
              }
            })
          }

          return Observable.forkJoin(queries)
            .delayWhen(() => Observable.timer(500 + startTime - Date.now()))
            .mergeMap(data => {
              const items =
                data.map(project => {
                  return project.data.projectBySlug
                }) || []
              return Observable.of({
                type: actions.ASSETS_FETCH_SUCCESS,
                payload: {
                  items,
                  isLoading: false,
                  error: false
                }
              })
            })
            .catch(error => {
              Raven.captureException(error)
              return Observable.of({
                type: actions.ASSETS_FETCH_FAILED,
                payload: error
              })
            })
        }
      )
    })
