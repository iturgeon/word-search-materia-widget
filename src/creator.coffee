WordSearchCreator = angular.module('wordSearchCreator', [])
WordSearchCreator.directive('ngEnter', ->
    return (scope, element, attrs) ->
        element.bind("keydown keypress", (event) ->
            if(event.which == 13)
                scope.$apply ->
                    scope.$eval(attrs.ngEnter)
                event.preventDefault()
        )
)
WordSearchCreator.directive('focusMe', ['$timeout', '$parse', ($timeout, $parse) ->
	link: (scope, element, attrs) ->
		model = $parse(attrs.focusMe)
		scope.$watch model, (value) ->
			if value
				$timeout ->
					element[0].focus()
			value
])

WordSearchCreator.controller 'wordSearchCreatorCtrl', ['$scope', ($scope) ->
	_context = _title = _qset = _hasFreshPuzzle = null
	_validRegex = new RegExp(' +?', 'g')

	$scope.widget =
		title: 'New Word Search Widget'
		words: []
		diagonal: true
		backwards: true
		tooManyWords: ''
		hasInvalidWords: false
		emptyPuzzle: true

	$scope.wordIsValid = (word) ->
		word.q.replace(_validRegex, '').length >= 2

	# Public interfaces
	$scope.initNewWidget = (widget, baseUrl) ->
		initDOM()
		$scope.$apply ->
			$scope.showIntroDialog = true

	$scope.initExistingWidget = (title,widget,qset,version,baseUrl) ->
		initDOM()

		_qset = qset
		if _qset.items[0] and _qset.items[0].items?
			_qset.items = _qset.items[0].items

		$scope.$apply ->
			$scope.widget.title = title

		$scope.onQuestionImportComplete qset.items, false

		$scope.generateNewPuzzle()

	$scope.onMediaImportComplete = (media) -> null

	$scope.onQuestionImportComplete = (questions,generate=true) ->
		for question in questions
			$scope.widget.words.push q: question.questions[0].text, id: question.id
		$scope.$apply()

		_buildSaveData() if generate

	$scope.onSaveClicked = ->
		return Materia.CreatorCore.cancelSave 'Widget needs a title' if not $scope.widget.title
		return Materia.CreatorCore.cancelSave 'All words must be at least two characters long' if $scope.widget.hasInvalidWords
		return Materia.CreatorCore.cancelSave 'You must have at least one valid word' if $scope.widget.emptyPuzzle

		Materia.CreatorCore.save $scope.widget.title, _buildSaveData()

	$scope.onSaveComplete = -> null

	# View actions
	$scope.addPuzzleItem = (q='',id='') ->
		$scope.widget.words.push q: q, id: id

	$scope.removePuzzleItem = (index) ->
		$scope.widget.words.splice(index,1)
		$scope.generateNewPuzzle()

	$scope.setTitle = ->
		$scope.widget.title = $scope.introTitle or $scope.widget.title
		$scope.step = 1
		$scope.hideCover()

	$scope.hideCover = ->
		$scope.showTitleDialog = $scope.showIntroDialog = false

	# Helper functions
	initDOM = ->
		_context = document.getElementById('canvas').getContext('2d')
		$scope.$apply ->
			$scope.generateNewPuzzle = (index) ->
				$scope.widget.words[index].q = $scope.widget.words[index].q.toLowerCase()
				_hasFreshPuzzle = false
				_buildSaveData()

	_buildSaveData = ->
		if not _hasFreshPuzzle
			a = []

			_qset =
				assets: []
				items: []
				options: {}
				rand: false
				name: ''

			$scope.widget.hasInvalidWords = false

			for word in $scope.widget.words
				if not $scope.wordIsValid(word)
					$scope.widget.hasInvalidWords = true
					continue

				a.push word.q

				_qset.items.push
					type: 'QA'
					id: word.id
					questions: [text: word.q]
					answers: [text: word.q, id: '']

			$scope.widget.emptyPuzzle = a.length is 0

			return if $scope.widget.emptyPuzzle

			puzzleSpots = WordSearch.Puzzle.makePuzzle a, $scope.widget.backwards, $scope.widget.diagonal

			spots = ""

			x = 1
			y = 1

			for spot in puzzleSpots
				for letter in spot
					spots += letter
					x++
				y++
				x = 0

			_qset.options.puzzleHeight = puzzleSpots.length
			_qset.options.puzzleWidth = puzzleSpots[0].length
			_qset.options.spots = spots
			_qset.options.wordLocations = WordSearch.Puzzle.getFinalWordPositionsString()

			locs = _qset.options.wordLocations.split(',')

			WordSearch.Puzzle.solvedRegions.length = 0

			for i in [0...locs.length-1] by 4
				WordSearch.Puzzle.solvedRegions.push
					x: ~~locs[i]
					y: ~~locs[i+1] + 1
					endx: ~~locs[i+2]
					endy: ~~locs[i+3] + 1

			_hasFreshPuzzle = true

		WordSearch.Puzzle.drawBoard(_context, _qset)

		$scope.widget.tooManyWords = if _qset.options.puzzleWidth > 19 then 'show' else ''

		_qset

	Materia.CreatorCore.start $scope
]
