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



def test_tumblr():
    posts = Tumblr.parse_api_response(TUMBLR_RESPONSE)
    assert len(posts) == 1
    post = posts[0]
    assert isinstance(post, Tumblr)
    assert post.image_size == [512, 342]
    assert post.image_url == u'http://25.media.tumblr.com/8d0d3e8925e12c53e8221b63411b40ed/tumblr_mfnglshzWY1qz6f9yo1_1280.jpg'
    assert post.title == u'nevver:\n\nKnock loud, I\u2019m home.'
    assert post.id is not None
    assert post._timestamp is not None


def test_instagram():
    media = Instagram.parse_api_response(INSTAGRAM_RESPONSE)
