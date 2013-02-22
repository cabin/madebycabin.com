import json
import pytest

from cabin.models import Tumblr, Instagram, Flickr


TUMBLR_RESPONSE = json.loads(r'''
{
  "meta": {
    "msg": "OK", 
    "status": 200
  }, 
  "response": {
    "blog": {
      "ask": false, 
      "ask_anon": false, 
      "description": "Cabin is a digital product design and development studio in Portland, Oregon.", 
      "name": "madebycabin", 
      "posts": 1, 
      "share_likes": false, 
      "title": "CABIN", 
      "updated": 1356572556, 
      "url": "http://madebycabin.tumblr.com/"
    }, 
    "posts": [
      {
        "blog_name": "madebycabin", 
        "caption": "nevver:\n\nKnock loud, I\u2019m home.", 
        "date": "2012-12-27 01:42:36 GMT", 
        "format": "html", 
        "highlighted": [], 
        "id": 38913831900, 
        "image_permalink": "http://madebycabin.tumblr.com/image/38913831900", 
        "link_url": "http://thomasmayerarchive.de/details.php?image_id=168802&l=english", 
        "note_count": 1093, 
        "photos": [
          {
            "alt_sizes": [
              {
                "height": 342, 
                "url": "http://25.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_1280.jpg", 
                "width": 512
              }, 
              {
                "height": 334, 
                "url": "http://24.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_500.jpg", 
                "width": 500
              }, 
              {
                "height": 267, 
                "url": "http://24.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_400.jpg", 
                "width": 400
              }, 
              {
                "height": 167, 
                "url": "http://25.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_250.jpg", 
                "width": 250
              }, 
              {
                "height": 67, 
                "url": "http://25.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_100.jpg", 
                "width": 100
              }, 
              {
                "height": 75, 
                "url": "http://25.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_75sq.jpg", 
                "width": 75
              }
            ], 
            "caption": "", 
            "original_size": {
              "height": 342, 
              "url": "http://25.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_1280.jpg", 
              "width": 512
            }
          }
        ], 
        "post_url": "http://madebycabin.tumblr.com/post/38913831900/nevver-knock-loud-im-home", 
        "reblog_key": "J7w7blhB", 
        "short_url": "http://tmblr.co/ZqSmTtaFSVFS", 
        "slug": "nevver-knock-loud-im-home", 
        "source_title": "thomasmayerarchive.de", 
        "source_url": "http://thomasmayerarchive.de/details.php?image_id=168802&l=english", 
        "state": "published", 
        "tags": [], 
        "timestamp": 1356572556, 
        "type": "photo"
      }
    ], 
    "total_posts": 1
  }
}''')

INSTAGRAM_RESPONSE = json.loads('''
{
  "data": [{
    "comments": {
      "data": [],
      "count": 0
    },
    "caption": {
      "created_time": "1296710352",
      "text": "Inside le truc #foodtruck",
      "from": {
        "username": "kevin",
        "full_name": "Kevin Systrom",
        "type": "user",
        "id": "3"
      },
      "id": "26621408"
    },
    "likes": {
      "count": 15,
      "data": [{
        "username": "mikeyk",
        "full_name": "Mike Krieger",
        "id": "4",
        "profile_picture": "..."
      }, {}]
    },
    "link": "http://instagr.am/p/BWrVZ/",
    "user": {
      "username": "kevin",
      "profile_picture": "http://distillery.s3.amazonaws.com/profiles/profile_3_75sq_1295574122.jpg",
      "id": "3"
    },
    "created_time": "1296710327",
    "images": {
      "low_resolution": {
        "url": "http://distillery.s3.amazonaws.com/media/2011/02/02/6ea7baea55774c5e81e7e3e1f6e791a7_6.jpg",
        "width": 306,
        "height": 306
      },
      "thumbnail": {
        "url": "http://distillery.s3.amazonaws.com/media/2011/02/02/6ea7baea55774c5e81e7e3e1f6e791a7_5.jpg",
        "width": 150,
        "height": 150
      },
      "standard_resolution": {
        "url": "http://distillery.s3.amazonaws.com/media/2011/02/02/6ea7baea55774c5e81e7e3e1f6e791a7_7.jpg",
        "width": 612,
        "height": 612
      }
    },
    "type": "image",
    "filter": "Earlybird",
    "tags": ["foodtruck"],
    "id": "22721881",
    "location": {
      "latitude": 37.778720183610183,
      "longitude": -122.3962783813477,
      "id": "520640",
      "street_address": "",
      "name": "Le Truc"
    }
  }]
}''')

FLICKR_RESPONSE = json.loads('''
{ "photoset": { "id": "72157625318124931", "primary": "5197783792", "owner": "53937539@N07", "ownername": "Church of Zek",
    "photo": [
      { "id": "5197783792", "secret": "128a1d3c72", "server": "4111", "farm": 5, "title": "", "isprimary": 0, "url_m": "http:\/\/farm5.staticflickr.com\/4111\/5197783792_128a1d3c72.jpg", "height_m": "333", "width_m": "500", "datetaken": "2010-08-20 23:06:57", "datetakengranularity": 0, "pathalias": "churchofzek" },
      { "id": "5197784012", "secret": "9e8b9f9552", "server": "4145", "farm": 5, "title": "", "isprimary": 0, "url_m": "http:\/\/farm5.staticflickr.com\/4145\/5197784012_9e8b9f9552.jpg", "height_m": "333", "width_m": "500", "datetaken": "2010-08-20 23:07:00", "datetakengranularity": 0, "pathalias": "churchofzek" },
      { "id": "5197784242", "secret": "43e1c7e988", "server": "4133", "farm": 5, "title": "", "isprimary": 0, "url_m": "http:\/\/farm5.staticflickr.com\/4133\/5197784242_43e1c7e988.jpg", "height_m": "333", "width_m": "500", "datetaken": "2010-08-20 23:10:48", "datetakengranularity": 0, "pathalias": "churchofzek" }
    ], "page": 1, "per_page": 3, "perpage": 3, "pages": 66, "total": "198" }, "stat": "ok" }
''')


def test_tumblr():
    posts = Tumblr.parse_api_response(TUMBLR_RESPONSE)
    assert len(posts) == 1
    post = posts[0]
    assert isinstance(post, Tumblr)
    assert post.is_valid()
    assert post.image_size == [512, 342]
    assert post.image_url == u'http://25.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_1280.jpg'
    assert post.title == u'nevver:\n\nKnock loud, I\u2019m home.'
    assert post.id is not None
    assert post._timestamp is not None


def test_instagram():
    media = Instagram.parse_api_response(INSTAGRAM_RESPONSE)


def test_flickr():
    photos = list(Flickr.parse_api_response(FLICKR_RESPONSE))
    assert len(photos) == 3
    photo = photos[0]
    assert isinstance(photo, Flickr)
    assert photo.is_valid()
    assert photo.image_size == [500, 333]
    assert photo.image_url == 'http://farm5.staticflickr.com/4111/5197783792_128a1d3c72.jpg'
    assert photo.link == 'http://www.flickr.com/photos/churchofzek/5197783792'
    assert photo.id is not None
    assert photo._timestamp is not None
