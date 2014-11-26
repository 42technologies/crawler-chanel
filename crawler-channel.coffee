
_        = require 'lodash'
url      = require 'url'
Crawler  = require('./crawler').Crawler
assert   = require 'assert'
Promise  = require 'bluebird'
request  = require 'request'
exec     = require('child_process').exec
fs       = Promise.promisifyAll(require('fs'))
path     = require 'path'

Promise.longStackTraces()

copy = (x) -> JSON.parse JSON.stringify(x)


ChannelCrawler = (crawler, baseUrl = '') ->

    headers =
        "User-Agent":       "Dudebro Crawler"
        "Accept-Encoding":  ""
        "Accept-Language":  "en-US,en;q=0.8"
        "Accept":           "application/json, text/javascript, */*; q=0.01"
        "Connection":       "keep-alive"
        "Pragma":           "no-cache"
        "Cache-Control":    "no-cache"


    crawl = (uri) -> new Promise (resolve, reject) ->
        console.trace() if not uri
        console.error "Queuing #{uri}"
        crawler.queue {uri, jquery:true, headers, callback:(err, res, $) ->
            return reject err if err
            return resolve {res, $}
        }


    crawlDetails = (url, parent) -> (crawl url).then ({$}) ->
        results = []
        $dataSource = $($('.product_form .data_source')[0])
        $options = $dataSource.find('option')

        if parent.category isnt 'fragrance'
            $options = $($options[0])

        $options.each (i, optionEl) ->
            $optionEl = $(optionEl)
            value = $optionEl.attr('data-json')
            data = JSON.parse(value)

            item = _.extend {}, parent,
                id:        data.skuId
                family:    data.productTitle.toLowerCase()
                name:      data.productSubTitle.toLowerCase()
                image:     data.imgUrl
                # size:      null
                # color:     null
                type:      data.type
                price:     parseFloat(data.price.value)

            _.keys(item).forEach (prop) -> assert not _.isUndefined item[prop], do ->
                "prop `#{prop}` is undefined\n#{JSON.stringify(item, null, 2)}"

            results.push(item)

        return results


    crawlSection = (section) -> (crawl section.url).then ({$}) ->
        results = []
        $('.products_container .product_container').each (i, productEl) ->
            $productEl = $(productEl)
            fields = do ->
                fields = {}
                $productEl.find('input').each (i, inputEl) ->
                    $inputEl = $(inputEl)
                    key   = $inputEl.attr('name')
                    value = $inputEl.attr('value')
                    fields[key] = value
                return fields
            url = fields.skuUrl
            data = _.omit(section, 'url')
            results.push crawlDetails(url, data)

        return Promise.all(results)


    crawl: ->
        sections = [
            {
                category: 'makeup'
                subcategory: 'makeup - face'
                url: 'http://www.chanel.com/en_US/fragrance-beauty/Makeup-Face-88486'
            }
            {
                category: 'makeup'
                subcategory: 'makeup - eyes'
                url: 'http://www.chanel.com/en_US/fragrance-beauty/Makeup-Eyes-89090'
            }
            {
                category: 'makeup'
                subcategory: 'makeup - lips'
                url: 'http://www.chanel.com/en_US/fragrance-beauty/Makeup-Lips-88719'
            }
            {
                category: 'makeup'
                subcategory: 'makeup - nails'
                url: 'http://www.chanel.com/en_US/fragrance-beauty/Makeup-Nails-89313'
            }
            {
                category: 'makeup'
                subcategory: 'makeup - brushes & accessories'
                url: 'http://www.chanel.com/en_US/fragrance-beauty/Makeup-Brushes-%26-Accessories-89291'
            }
            {
                category: 'fragrance'
                subcategory: 'fragrance - women'
                url:      'http://www.chanel.com/en_US/fragrance-beauty/Fragrance-Women-88108'
            }
            {
                category: 'fragrance'
                subcategory: 'fragrance - men'
                url:      'http://www.chanel.com/en_US/fragrance-beauty/Fragrance-Men-88358'
            }
        ]
        Promise.all(sections.map(crawlSection)).then (data) -> (_.flatten data)


crawler = new Crawler
    maxConnections:    100
    autoWindowClose:   true
    discoverResources: false


crawler = new ChannelCrawler(crawler)

crawler.crawl()
.then (result) ->
    fs.writeFileAsync('./data.json', JSON.stringify(result, null, 2))
.done ->
    console.log "DONE!"
    process.exit()
