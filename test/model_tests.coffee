Model = require '../src'
keygen = require 'keygen'
{omit} = require 'lodash'
pipeline = require '../src/pipeline'

describe 'Model Tests', ->

  beforeEach (done) ->
    @timeout 20000
    clean_db done

  describe 'constructor', ->

    it 'it should construct with name', ->
      model = new Model 'table_one'
      model.name.should.eql 'table_one'

    it 'should default key size', ->
      model = new Model 'table_one'
      model.key_size.should.eql keygen.large

    it 'should apply extensions', ->
      model = new Model 'table_one', foo: 'bar', baz: 'qak'
      model.should.have.property 'foo'
      model.foo.should.eql 'bar'
      model.should.have.property 'baz'
      model.baz.should.eql 'qak'

    it 'should allow key size override', ->
      model = new Model 'table_one', key_size: keygen.small
      model.key_size.should.eql keygen.small

  describe '#model', ->

    it 'should attach exports to context', ->
      context = {}
      model = Model.model 'table_one', foo: 'bar'
      model.name.should.eql 'table_one'
      model.foo.should.eql 'bar'

  describe '#extend', ->

    it 'should attach exports to context', ->
      context = {}
      Model.extend context, 'table_one', foo: 'bar'
      context.should.have.property 'exports'
      context.exports.name.should.eql 'table_one'
      context.exports.foo.should.eql 'bar'

    it 'should attach exports to context', ->
      test_model = require './test_model'
      test_model.name.should.eql 'table_one'
      test_model.foo.should.eql 'bar'



  describe 'instance', ->

    model = undefined

    beforeEach ->
      model = new Model 'table_one'

    describe '.key_for', ->

      it 'should extract key from item', ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        key = model._key_for item
        key.should.eql identifier: '12312'

      it 'should allow hash key override', ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        model = new Model 'table_one', hash_key: 'foo'
        key = model._key_for item
        key.should.eql foo: 'bar'

      it 'should allow range key override', ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        model = new Model 'table_one', range_key: 'baz'
        key = model._key_for item
        key.should.eql identifier: '12312', baz: 'quk'

      it 'should allow hash and range key overrides', ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        model = new Model 'table_one', hash_key: 'foo', range_key: 'baz'
        key = model._key_for item
        key.should.eql foo: 'bar', baz: 'quk'

      it 'should allow raw hash values', ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        model = new Model 'table_one', hash_key: 'foo'
        key = model._key_for ['12312']
        key.should.eql foo: '12312'

    describe '.put', ->

      it 'should proxy put and create params', (done) ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        model._request = (method, params) ->
          method.should.eql 'put'
          params.should.have.property 'Item'
          omit(params.Item, 'created_at', 'updated_at').should.eql item
          Promise.resolve()
        model.put(item)
          .then -> done()
          .catch done

      it 'should map condition params', (done) ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        condition_params =
          condition: '#field = :value'
          names: {'#feild': 'field'}
          values: {':value': 'value'}
        model._request = (method, params) ->
          params.should.have.property 'ConditionExpression'
          params.ConditionExpression.should.eql condition_params.condition
          params.should.have.property 'ExpressionAttributeNames'
          params.ExpressionAttributeNames.should.eql condition_params.names
          params.should.have.property 'ExpressionAttributeValues'
          params.ExpressionAttributeValues.should.eql condition_params.values
          Promise.resolve()
        model.put(item, condition_params)
          .then -> done()
          .catch done

      it 'should map condition params without prefix', (done) ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        condition_params =
          condition: '#field = :value'
          names: {'feild': 'field'}
          values: {'value': 'value'}
        model._request = (method, params) ->
          params.should.have.property 'ConditionExpression'
          params.ConditionExpression.should.eql condition_params.condition
          params.should.have.property 'ExpressionAttributeNames'
          params.ExpressionAttributeNames.should.eql {'#feild': 'field'}
          params.should.have.property 'ExpressionAttributeValues'
          params.ExpressionAttributeValues.should.eql {':value': 'value'}
          Promise.resolve()
        model.put(item, condition_params)
          .then -> done()
          .catch done

      it 'should add identifier', (done) ->
        item = foo: 'bar', baz: 'quk'
        model._request = (method, params) ->
          params.Item.should.have.property 'identifier'
          Promise.resolve()
        model.put(item)
          .then -> done()
          .catch done

      it 'should not add identifier for other hash_key', (done) ->
        item = foo: 'bar', baz: 'quk'
        model.hash_key = 'not_identifier'
        model._request = (method, params) ->
          params.Item.should.not.have.property 'identifier'
          Promise.resolve()
        model.put(item)
          .then -> done()
          .catch done

      it 'should propagate error', (done) ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        model._request = (method, params) ->
          Promise.reject 'some error'
        model.put(item)
          .then ->
            done 'Should not resolve'
          .catch (error) ->
            error.should.eql 'some error'
            done()

      it 'should handle simple put', (done) ->
        item = identifier: '12312', foo: 'bar', baz: 'quk'
        model.put(item)
          .then ->
            item.should.not.be.null
            model.scan().then (items) ->
              items.length.should.eql 1
              items[0].should.eql item
              done()
          .catch done

      it 'should handle conditional put', (done) ->
        item = identifier: '12312', foo: 'bar', baz: 'qak'
        model.put(item).then ->
          model.put({identifier: '12312', foo: 'qak', baz: 'bar'}, condition: '#identifier <> :identifier', names: {'#identifier': 'identifier'}, values: {':identifier': '12312'})
            .then ->
              done 'should have failed due to conditional check'
            .catch (err) ->
              err.should.not.be.null
              done()

      describe 'auto_timestamps', ->

        it 'should apply timestaps if true', (done) ->
            item = identifier: '12312', foo: 'bar', baz: 'qak'
            model.auto_timestamps = true
            model.put(item)
              .then (item) ->
                item.should.have.property 'created_at'
                item.should.have.property 'updated_at'
                done()
              .catch done

        it 'should not apply timestaps if false', (done) ->
            item = identifier: '12312', foo: 'bar', baz: 'qak'
            model.auto_timestamps = false
            model.put(item)
              .then (item) ->
                item.should.not.have.property 'created_at'
                item.should.not.have.property 'updated_at'
                done()
              .catch done

        it 'should not override created_at at', (done) ->
            item = identifier: '12312', foo: 'bar', baz: 'qak', created_at: new Date()
            model.auto_timestamps = true
            model.put(item)
              .then (after) ->
                after.created_at.should.eql item.created_at
                done()
              .catch done

        it 'should override updated_at ', (done) ->
            item = identifier: '12312', foo: 'bar', baz: 'qak', updated_at: new Date(0)
            model.auto_timestamps = true
            model.put(item)
              .then (after) ->
                after.updated_at.should.not.eql item.updated_at
                done()
              .catch done
    #
    # describe '.put_all', ->
    #
    #   it 'should proxy put and create params', (done) ->
    #     item1 = identifier: '12312', foo: 'bar', baz: 'qak'
    #     item2 = identifier: '21321', foo: 'qak', baz: 'bar'
    #     model._request = (method, params, include_table) ->
    #       method.should.eql 'batchWrite'
    #       params.should.have.property 'RequestItems'
    #       params.RequestItems.should.have.property 'table_one'
    #       params.RequestItems.table_one.length.should.eql 2
    #       omit(params.RequestItems.table_one[0].PutRequest.Item, 'created_at', 'updated_at').should.eql item1
    #       omit(params.RequestItems.table_one[1].PutRequest.Item, 'created_at', 'updated_at').should.eql item2
    #       include_table.should.eql false
    #       Promise.resolve()
    #     model.put_all([item1, item2])
    #       .then -> done()
    #       .catch done
    #
    #   it 'should put items', (done) ->
    #     item1 = identifier: '12312', foo: 'bar', baz: 'qak'
    #     item2 = identifier: '21321', foo: 'qak', baz: 'bar'
    #     model.put_all([item1, item2])
    #       .then ->
    #         model.scan().then (items) ->
    #           items.length.should.eql 2
    #           done()
    #       .catch done
    #
    #   it 'should propagate error', (done) ->
    #     item = identifier: '12312', foo: 'bar', baz: 'quk'
    #     model._request = (method, params) ->
    #       Promise.reject 'some error'
    #     model.put_all([item])
    #       .then ->
    #         done 'Should not resolve'
    #       .catch (error) ->
    #         error.should.eql 'some error'
    #         done()
    #
    #   describe 'auto_timestamps', ->
    #
    #     it 'should apply timestaps if true', (done) ->
    #         item1 = identifier: '12312', foo: 'bar', baz: 'qak'
    #         item2 = identifier: '2345', foo: 'bar', baz: 'qak'
    #         model.auto_timestamps = true
    #         model.put_all([item1, item2]).then (items) ->
    #           items[0].should.have.property 'created_at'
    #           items[0].should.have.property 'updated_at'
    #           items[1].should.have.property 'created_at'
    #           items[1].should.have.property 'updated_at'
    #           done()
    #
    #     it 'should not apply timestaps if false', (done) ->
    #         item1 = identifier: '12312', foo: 'bar', baz: 'qak'
    #         item2 = identifier: '2345', foo: 'bar', baz: 'qak'
    #         model.auto_timestamps = false
    #         model.put_all([item1, item2]).then (items) ->
    #           items[0].should.not.have.property 'created_at'
    #           items[0].should.not.have.property 'updated_at'
    #           items[1].should.not.have.property 'created_at'
    #           items[1].should.not.have.property 'updated_at'
    #           done()
    #
    #     it 'should not override created_at at', (done) ->
    #         item1 = identifier: '12312', foo: 'bar', baz: 'qak', created_at: new Date()
    #         item2 = identifier: '2345', foo: 'bar', baz: 'qak', created_at: new Date()
    #         model.auto_timestamps = true
    #         model.put_all([item1, item2]).then (items) ->
    #           items[0].created_at.should.eql item1.created_at
    #           items[1].created_at.should.eql item2.created_at
    #           done()
    #
    #     it 'should override updated_at ', (done) ->
    #         item1 = identifier: '12312', foo: 'bar', baz: 'qak', updated_at: new Date()
    #         item2 = identifier: '2345', foo: 'bar', baz: 'qak', updated_at: new Date()
    #         model.auto_timestamps = true
    #         model.put_all([item1, item2]).then (items) ->
    #           items[0].updated_at.should.eql item1.updated_at
    #           items[1].updated_at.should.eql item2.updated_at
    #           done()
    #
    describe.only '.insert', ->

      it 'should proxy to put and create condition', (done) ->
        item = foo: 'bar', baz: 'qak'
        model.put = (item, condition) ->
          condition.should.not.be.null
          condition.condition.should.eql 'identifier <> :identifier'
          condition.values.should.eql ':identifier': item.identifier
          Promise.resolve(item)
        model.insert(item)
          .then -> done()
          .catch done

      it 'should propagate error', (done) ->
        item = foo: 'bar', baz: 'quk'
        model._request = (method, params) ->
          Promise.reject 'some error'
        model.insert(item)
          .then ->
            done 'Should not resolve'
          .catch (error) ->
            error.should.eql 'some error'
            done()

      it 'should handle simple insert', (done) ->
        item = foo: 'bar', baz: 'quk'
        model.insert(item)
          .then (item) ->
            item.should.not.be.null
            model.scan().then (items) ->
              items.length.should.eql 1
              done()
          .catch done

      it 'should disallow insert with same identifier', (done) ->
        item = identifier: '12312', foo: 'bar', baz: 'qak'
        model.insert(item).then ->
          model.insert({identifier: '12312', foo: 'qak', baz: 'bar'})
            .then ->
              done 'should have failed due to conditional check'
            .catch (err) ->
              err.should.not.be.null
              done()

    describe '.update', ->

      it 'should proxy to update and setup key', (done) ->
        key = identifier: '12312'
        model._request = (method, params) ->
          method.should.eql 'update'
          params.Key.should.eql key
          Promise.resolve(Items: [])
        model.update(key, {})
          .then -> done()
          .catch done

      it 'should proxy to update and setup condition', (done) ->
        key = identifier: '12312'
        condition =
          expression: 'SET #name = :value'
          names:
            '#name': 'name'
          values:
            ':value': 'value'
        model._request = (method, params) ->
          params.should.have.property 'UpdateExpression'
          params.UpdateExpression.should.eql condition.expression
          params.should.have.property 'ExpressionAttributeNames'
          params.ExpressionAttributeNames.should.eql condition.names
          params.should.have.property 'ExpressionAttributeValues'
          params.ExpressionAttributeValues.should.eql condition.values
          Promise.resolve(Items: [])
        model.update({identifier: '12312'}, condition)
          .then -> done()
          .catch done

      it 'should propagate error', (done) ->
        item = foo: 'bar', baz: 'quk'
        model._request = (method, params) ->
          Promise.reject 'some error'
        model.update(item, {})
          .then ->
            done 'Should not resolve'
          .catch (error) ->
            error.should.eql 'some error'
            done()

      it 'should handle update', (done) ->
        item = identifier: '1234', foo: 'bar', baz: 'quk'
        model.put(item)
          .then (item) ->
            model.update(item, expression: 'SET foo = :value', values: {':value': 'clk'})
              .then ->
                model.scan().then (items) ->
                  items.length.should.eql 1
                  items[0].foo.should.eql 'clk'
                  done()
          .catch done

      it 'should handle missing key', (done) ->
        item = identifier: '1234', foo: 'bar', baz: 'quk'
        model.update(item, expression: 'SET foo = :value', values: {':value': 'clk'})
          .then (updated) ->
            updated.should.not.be.null
            updated.foo.should.eql 'clk'
            model.scan().then (items) ->
              items.length.should.eql 1
              items[0].foo.should.eql 'clk'
              items[0].should.not.have.property 'baz'
              done()
          .catch done
    
    # describe '.get', ->
    #
    #   it 'should proxy get and setup key param', (done) ->
    #     key = identifier: '12312'
    #     model._request = (method, params) ->
    #       method.should.eql 'get'
    #       params.should.have.property 'Key'
    #       params.Key.should.eql key
    #       Promise.resolve()
    #     model.get(key)
    #       .then -> done()
    #       .catch done
    #
    #   it 'should map projection params', (done) ->
    #     key = identifier: '12312'
    #     projection_params =
    #       projection: '#field'
    #       names: {'#feild': 'field'}
    #     model._request = (method, params) ->
    #       params.should.have.property 'ProjectionExpression'
    #       params.ProjectionExpression.should.eql projection_params.projection
    #       params.should.have.property 'ExpressionAttributeNames'
    #       params.ExpressionAttributeNames.should.eql projection_params.names
    #       Promise.resolve()
    #     model.get(key, projection_params)
    #       .then -> done()
    #       .catch done
    #
    #   it 'should propagate error', (done) ->
    #     key = identifier: '12312'
    #     model._request = (method, params) ->
    #       Promise.reject 'some error'
    #     model.get(key)
    #       .then ->
    #         done 'Should not resolve'
    #       .catch (error) ->
    #         error.should.eql 'some error'
    #         done()
    #
    #   it 'should handle get', (done) ->
    #     item = identifier: '12312', foo: 'bar', baz: 'quk'
    #     key = identifier: '12312'
    #     model.put(item)
    #       .then ->
    #         model.get(key).then (actual)->
    #           actual.should.not.be.null
    #           actual.should.eql item
    #           done()
    #       .catch done
    #
    #   it 'should handle get with raw hash', (done) ->
    #     item = identifier: '12312', foo: 'bar', baz: 'quk'
    #     model.put(item)
    #       .then ->
    #         model.get('12312').then (actual)->
    #           actual.should.not.be.null
    #           actual.should.eql item
    #           done()
    #       .catch done
    #
    #   it 'should handle get with raw hash and range', (done) ->
    #     item = identifier: '12312', range_key: 'bar'
    #     model = new Model 'table_two', range_key: 'range_key'
    #     model.put(item)
    #       .then ->
    #         model.get('12312', 'bar').then (actual) ->
    #           actual.should.not.be.null
    #           actual.should.eql item
    #           done()
    #       .catch done
    #
    #   it 'should handle unknown key', (done) ->
    #     key = identifier: '12312'
    #     model.get(key)
    #       .then (actual) ->
    #         expect(actual).to.be.nil
    #         done()
    #       .catch (err) -> console.log err
    #
    # describe '.delete', ->
    #
    #   it 'should proxy delete and setup key param', (done) ->
    #     key = identifier: '12312'
    #     model._request = (method, params) ->
    #       method.should.eql 'delete'
    #       params.should.have.property 'Key'
    #       params.Key.should.eql key
    #       Promise.resolve()
    #     model.delete(key)
    #       .then -> done()
    #       .catch done
    #
    #   it 'should map condition params', (done) ->
    #     key = identifier: '12312'
    #     condition_params =
    #       condition: '#field = :value'
    #       names: {'#feild': 'field'}
    #       values: {':value': 'value'}
    #     model._request = (method, params) ->
    #       params.should.have.property 'ConditionExpression'
    #       params.ConditionExpression.should.eql condition_params.condition
    #       params.should.have.property 'ExpressionAttributeNames'
    #       params.ExpressionAttributeNames.should.eql condition_params.names
    #       params.should.have.property 'ExpressionAttributeValues'
    #       params.ExpressionAttributeValues.should.eql condition_params.values
    #       Promise.resolve()
    #     model.delete(key, condition_params)
    #       .then -> done()
    #       .catch done
    #
    #   it 'should propagate error', (done) ->
    #     key = identifier: '12312'
    #     model._request = (method, params) ->
    #       Promise.reject 'some error'
    #     model.delete(key)
    #       .then ->
    #         done 'Should not resolve'
    #       .catch (error) ->
    #         error.should.eql 'some error'
    #         done()
    #
    #   it 'should handle delete', (done) ->
    #     item = identifier: '12312', foo: 'bar', baz: 'quk'
    #     key = identifier: '12312'
    #     model.put(item)
    #       .then ->
    #         model.delete(key).then ->
    #           model.scan().then (items) ->
    #               items.length.should.eql 0
    #               done()
    #       .catch done
    #
    describe '.query', ->

      it 'should proxy query and setup key param', (done) ->
        query =
          expression: '#identifier = :identifier'
          filter: '#foo = :bar'
          names:
            '#identifier': 'identifier'
            '#foo': 'foo'
          values:
            ':identifier': '1234'
            ':bar': 'baz'
          index: 'secondary_index'
          limit: 10
          forward: false

        model._request = (method, params) ->
          method.should.eql 'query'
          params.should.have.property 'KeyConditionExpression'
          params.KeyConditionExpression.should.eql query.expression
          params.should.not.have.property 'expression'
          params.should.have.property 'ExpressionAttributeNames'
          params.ExpressionAttributeNames.should.eql query.names
          params.should.not.have.property 'names'
          params.should.have.property 'ExpressionAttributeValues'
          params.ExpressionAttributeValues.should.eql query.values
          params.should.not.have.property 'values'
          params.should.have.property 'FilterExpression'
          params.FilterExpression.should.eql query.filter
          params.should.not.have.property 'filter'
          params.should.have.property 'IndexName'
          params.IndexName.should.eql query.index
          params.should.not.have.property 'index'
          params.should.have.property 'Limit'
          params.Limit.should.eql query.limit
          params.should.not.have.property 'limit'
          params.should.have.property 'ScanIndexForward'
          params.ScanIndexForward.should.eql query.forward
          params.should.not.have.property 'forward'

          Promise.resolve(Items: [])
        model.query(query)
          .then -> done()
          .catch done

      it 'should propagate error', (done) ->
        model._request = (method, params) ->
          Promise.reject 'some error'
        query =
          expression: '#identifier = :identifier'
          names:
            '#identifier': 'identifier'
          values:
            ':identifier': '1234'
        model.query(query)
          .then ->
            done 'Should not resolve'
          .catch (error) ->
            error.should.eql 'some error'
            done()

      it 'should handle query', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'quk'
        item2 = identifier: '21321', foo: 'bar', baz: 'quk'
        key = identifier: '12312'
        query =
          expression: '#identifier = :identifier'
          names:
            '#identifier': 'identifier'
          values:
            ':identifier': item1.identifier
        model.put_all([item1, item2])
          .then ->
            model.query(query).then (results) ->
              results.length.should.eql 1
              results[0].should.eql item1
              done()
          .catch done

      it 'should handle query with no results', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'quk'
        item2 = identifier: '21321', foo: 'bar', baz: 'quk'
        key = identifier: '12312'
        query =
          expression: '#identifier = :identifier'
          names:
            '#identifier': 'identifier'
          values:
            ':identifier': 'not to be found'
        model.put_all([item1, item2])
          .then ->
            model.query(query).then (result) ->
              result.length.should.eql 0
              done()
          .catch done

    describe '.query_single', ->

      it 'should proxy to query and return first item', (done) ->
        query =
          expression: '#identifier = :identifier'
          values: ':identifier': '1234'
        model.query = (params) ->
          pipeline.source [{identifier: 'item1'}, {identifier: 'item2'}]
        model.query_single(query)
          .then (item) ->
            item.should.not.be.nil
            item.identifier.should.eql 'item1'
            done()
          .catch done

      it 'should proxy to query hadnle empty results', (done) ->
        query =
          expression: '#identifier = :identifier'
          values: ':identifier': '1234'
        model.query = (params) ->
          pipeline.source []
        model.query_single(query)
          .then (item) ->
            expect(item).to.be.nil
            done()
          .catch done


      it 'should propagate error', (done) ->
        model.query = (params) ->
          pipeline
            .source {}
            .pipe ->
              Promise.reject 'some error'
        query =
          expression: '#identifier = :identifier'
          names:
            '#identifier': 'identifier'
          values:
            ':identifier': '1234'
        model.query_single(query)
          .then ->
            done 'Should not resolve'
          .catch (error) ->
            error.should.eql 'some error'
            done()

      it 'should handle query', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'quk'
        item2 = identifier: '21321', foo: 'bar', baz: 'quk'
        key = identifier: '12312'
        query =
          expression: '#identifier = :identifier'
          names:
            '#identifier': 'identifier'
          values:
            ':identifier': item1.identifier
        model.put_all([item1, item2])
          .then ->
            model.query(query).then (results) ->
              results.length.should.eql 1
              results[0].should.eql item1
              done()
          .catch done

      it 'should handle query with no results', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'quk'
        item2 = identifier: '21321', foo: 'bar', baz: 'quk'
        key = identifier: '12312'
        query =
          expression: '#identifier = :identifier'
          names:
            '#identifier': 'identifier'
          values:
            ':identifier': 'not to be found'
        model.put_all([item1, item2])
          .then ->
            model.query_single(query).then (result) ->
              expect(result).to.be.nil
              done()
          .catch done

    describe '.scan', ->

      it 'should proxy scan and setup expression', (done) ->
        filter =
          filter: '#foo = :bar'
          names:
            '#foo': 'foo'
          values:
            ':bar': 'baz'
          limit: 10
        model._request = (method, params) ->
          method.should.eql 'scan'
          params.should.have.property 'FilterExpression'
          params.FilterExpression.should.eql filter.filter
          params.should.not.have.property 'expression'
          params.should.have.property 'ExpressionAttributeNames'
          params.ExpressionAttributeNames.should.eql filter.names
          params.should.not.have.property 'names'
          params.should.have.property 'ExpressionAttributeValues'
          params.ExpressionAttributeValues.should.eql filter.values
          params.should.not.have.property 'values'
          params.should.have.property 'Limit'
          params.Limit.should.eql filter.limit
          params.should.not.have.property 'limit'

          Promise.resolve(Items: [])
        model.scan(filter)
          .then -> done()
          .catch done

      it 'should propagate error', (done) ->
        model._request = (method, params) ->
          Promise.reject 'some error'
        filter =
          filter: '#foo = :bar'
          names:
            '#foo': 'foo'
          values:
            ':bar': 'baz'
          limit: 10
        model.scan(filter)
          .then ->
            done 'Should not resolve'
          .catch (error) ->
            error.should.eql 'some error'
            done()

      it 'should handle scan with no filter', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'qak'
        item2 = identifier: '21321', foo: 'qak', baz: 'bar'
        key = identifier: '12312'
        model.put_all([item1, item2])
          .then ->
            model.scan()
              .then (results) ->
                results.length.should.eql 2
                done()
          .catch done

      it 'should handle scan with filter', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'qak'
        item2 = identifier: '21321', foo: 'qak', baz: 'bar'
        key = identifier: '12312'
        filter =
          filter: '#foo = :foo'
          names:
            '#foo': 'foo'
          values:
            ':foo': item2.foo
        model.put_all([item1, item2])
          .then ->
            model.scan(filter).then (results) ->
              results.length.should.eql 1
              results[0].should.eql item2
              done()
          .catch done

      it 'should handle scan with no results', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'qak'
        item2 = identifier: '21321', foo: 'qak', baz: 'bar'
        key = identifier: '12312'
        filter =
          filter: '#foo = :foo'
          names:
            '#foo': 'foo'
          values:
            ':foo': 'not to be found'
        model.put_all([item1, item2])
          .then ->
            model.scan(filter).then (results) ->
              results.length.should.eql 0
              done()
          .catch done

      it 'should handle scan with limit', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'qak'
        item2 = identifier: '21321', foo: 'qak', baz: 'bar'
        key = identifier: '12312'
        model.put_all([item1, item2])
          .then ->
            model.scan(limit: 1).then (results) ->
              results.length.should.eql 1
              done()
          .catch done

    describe '.for_keys', ->

      it 'should proxy batchGet and setup expression', (done) ->
        keys = [
            {identifier: '12314'}
            {identifier: '23423'}
            {identifier: '43535'}
        ]
        model._request = (method, params) ->
          method.should.eql 'batchGet'
          params.should.have.property 'RequestItems'
          params.RequestItems.should.have.property 'table_one'
          params.RequestItems.table_one.should.have.property 'Keys'
          params.RequestItems.table_one.Keys.should.eql [
            {identifier: '12314'}
            {identifier: '23423'}
            {identifier: '43535'}
          ]
          Promise.resolve(Responses: table_one: [])
        model.for_keys(keys)
          .then -> done()
          .catch done

      it 'should propagate error', (done) ->
        model._request = (method, params) ->
          Promise.reject 'some error'
        keys = [
            {identifier: '12314'}
            {identifier: '23423'}
            {identifier: '43535'}
        ]
        model.for_keys(keys)
          .then ->
            done 'Should not resolve'
          .catch (error) ->
            error.should.eql 'some error'
            done()


      it 'should handle for keys', (done) ->
        item1 = identifier: '12312', foo: 'bar', baz: 'qak'
        item2 = identifier: '21321', foo: 'qak', baz: 'bar'
        keys = [
            {identifier: '12312'}
            {identifier: '21321'}
            {identifier: '43535'}
        ]
        model.put_all([item1, item2])
          .then ->
            model.for_keys(keys).then (results) ->
              results.length.should.eql 2
              done()
          .catch done