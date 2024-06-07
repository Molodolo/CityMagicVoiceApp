from flask import Flask, request, redirect, jsonify, render_template

app = Flask(__name__)

city_name = None


@app.route('/')
def home():
    try:
        return render_template('index.html')
    except Exception as e:
        return str(e), 500


@app.route('/search')
def search():
    global city_name
    city = request.args.get('city')
    if city:
        city_name = city
    return '', 204  # No Content response


@app.route('/check')
def check():
    global city_name
    if city_name:
        print(city_name)
        url = f'https://www.google.com/maps/search/{city_name}'
        city_name = None  # Reset city_name after using it
        return jsonify({'redirect': True, 'url': url})
    return jsonify({'redirect': False})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
