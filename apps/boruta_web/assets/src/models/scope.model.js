import axios from 'axios'

const defaults = {
  name: '',
  edit: false,
  errors: null
}

const assign = {
  id: function ({ id }) { this.id = id },
  name: function ({ name }) { this.name = name },
  edit: function ({ edit }) { this.edit = edit },
  public: function ({ public: e }) { this.public = e }
}
class Client {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  get persisted () {
    return !!this.id
  }

  reset () {
    return this.constructor.api().get(`/${this.id}`).then(({ data }) => {
      Object.assign(this, defaults)
      return Object.assign(this, data.data)
    })
  }

  save () {
    const { id, serialized } = this
    let response

    this.errors = null

    if (id) {
      response = this.constructor.api().patch(`/${id}`, { scope: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    } else {
      response = this.constructor.api().post('/', { scope: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    }
    return response.catch((error) => {
      const { errors } = error.response.data
      this.errors = errors
      throw errors
    })
  }

  destroy () {
    return this.constructor.api().delete(`/${this.id}`)
  }

  get serialized () {
    const { id, name, public: p } = this

    return {
      id,
      name,
      public: p
    }
  }
}

Client.api = function () {
  const accessToken = localStorage.getItem('vue-authenticate.vueauth_token')

  return axios.create({
    baseURL: `${process.env.VUE_APP_BORUTA_BASE_URL}/api/scopes`,
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
