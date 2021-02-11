import axios from 'axios'
import Scope from '@/models/scope.model'

const allGrantTypes = ['client_credentials', 'password', 'authorization_code', 'refresh_token', 'implicit']

const defaults = {
  authorize_scopes: false,
  authorized_scopes: [],
  redirect_uris: [],
  grantTypes: allGrantTypes.map((label) => {
    return {
      value: true,
      label
    }
  })
}

const assign = {
  id: function ({ id }) { this.id = id },
  pkce: function ({ pkce }) { this.pkce = pkce },
  authorization_code_ttl: function ({ authorization_code_ttl }) { this.authorization_code_ttl = authorization_code_ttl },
  access_token_ttl: function ({ access_token_ttl }) { this.access_token_ttl = access_token_ttl },
  secret: function ({ secret }) { this.secret = secret },
  redirect_uris: function ({ redirect_uris }) {
    this.redirect_uris = redirect_uris.map((uri) => ({ uri }))
  },
  authorize_scope: function ({ authorize_scope }) { this.authorize_scope = authorize_scope },
  authorized_scopes: function ({ authorized_scopes }) {
    this.authorized_scopes = authorized_scopes.map((scope) => {
      return { model: new Scope(scope) }
    })
  },
  supported_grant_types: function ({ supported_grant_types }) {
    this.supported_grant_types = supported_grant_types
    this.grantTypes = allGrantTypes.map((label) => {
      return {
        value: this.supported_grant_types.includes(label),
        label
      }
    })
  }
}

class Client {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  // TODO factorize with User#validate
  validate () {
    return new Promise((resolve, reject) => {
      this.authorized_scopes.forEach(({ model: scope }) => {
        if (!scope.persisted) {
          return reject({ authorized_scopes: [ 'cannot be empty' ] })
        }
        if (this.authorized_scopes.filter(({ model: e }) => e.id === scope.id).length > 1) {
          reject({ authorized_scopes: [ 'must be unique' ] })
        }
      })
      resolve()
    })
  }

  save () {
    // TODO trigger validate
    let response
    const { id, serialized } = this
    if (id) {
      response = this.constructor.api().patch(`/${id}`, { client: serialized })
    } else {
      response = this.constructor.api().post('/', { client: serialized })
    }

    return response
      .then(({ data }) => {
        const params = data.data

        Object.keys(params).forEach((key) => {
          this[key] = params[key]
          assign[key].bind(this)(params)
        })
        return this
      })
      .catch((error) => {
        const { errors } = error.response.data
        this.errors = errors
        throw errors
      })
  }

  destroy () {
    return this.constructor.api().delete(`/${this.id}`)
  }

  get serialized () {
    const { id, secret, redirect_uris, authorize_scope, authorized_scopes, grantTypes, access_token_ttl, authorization_code_ttl, pkce } = this

    return {
      id,
      secret,
      redirect_uris: redirect_uris.map(({ uri }) => uri),
      authorize_scope,
      access_token_ttl,
      authorization_code_ttl,
      pkce,
      authorized_scopes: authorized_scopes.map(({ model }) => model.serialized),
      supported_grant_types: grantTypes
        .filter(({ value }) => value)
        .map(({ label }) => label)
    }
  }
}

Client.api = function () {
  const accessToken = localStorage.getItem('access_token')

  return axios.create({
    baseURL: `${process.env.VUE_APP_BORUTA_BASE_URL}/oauth/api/clients`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })
}

Client.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((client) => new Client(client))
  })
}

Client.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new Client(data.data)
  })
}

export default Client