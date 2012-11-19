###
SemViz
A visualizer for Semafor parses

Requires jQuery, mustache

Author: Sam Thomson (sthomson@cs.cmu.edu)
###

# Mustache template for the frame visualization table
FRAME_TABLE_TEMPLATE = """
<table id=frame_table>
	<tr>
		<thead>
			<th></th>
			{{#targetHeaders}}
				<th class="target">
					<a href={{getUrl}}>{{label}}</a>
				</th>
			{{/targetHeaders}}
		</thead>
	</tr>
	{{#rows}}
		<tr id="token_{{token.idx}}">
			<th>{{token.label}}</th>
			{{#frames}}
				<td rowspan={{spanLength}}
						{{#isFrameElement}}
							class="annotation frame_element"
						{{/isFrameElement}}
						{{#isTarget}}
							class="annotation target"
						{{/isTarget}}
						>
					{{label}}
				</td>
			{{/frames}}
		</tr>
	{{/rows}}
</table>
"""
# link to the docs for a frame
FRAMENET_FRAME_URL_TEMPLATE = 'https://framenet2.icsi.berkeley.edu/fnReports/data/frame/{{name}}.xml'
# url of api endpoint to parse a sentence
PARSE_URL = "/api/v1/parse"
# the input textarea inwhich the user types the sentence to parse
INPUT_BOX_SELECTOR = "textarea[name=sentence]"
# the div in which to put the rendered html table representing the parse
FRAME_DISPLAY_SELECTOR = '#parse_table'

# Different types of cells in the table
class Cell
	constructor: (@label = '', @spanLength = 1) ->

class Header extends Cell
	constructor: (label, @idx) ->
		super(label = label)

class AnnotationCell extends Cell
	constructor: (span, @frameId) ->
		super(label = span.name, spanLength = span.end - span.start)
		@spanStart = span.start

class TargetCell extends AnnotationCell
	constructor: (target, frameId) ->
		super(target, frameId)
		@isTarget = true

	getUrl: () ->
		Mustache.to_html(FRAMENET_FRAME_URL_TEMPLATE, {name: @label})

class FrameElementCell extends AnnotationCell
	constructor: (fe, frameId) ->
		super(fe, frameId)
		@isFrameElement = true

BLANK = new Cell()

###
Main functionality of the Semafor visualization demo
###
class SemViz
	constructor: (
		@parseUrl = PARSE_URL,
		@inputArea = INPUT_BOX_SELECTOR,
		@displayDiv = FRAME_DISPLAY_SELECTOR
	) ->

	###
	Clears room for the given span if it is a multiword span.
	###
	makeRoom: (table, span, frameId) ->
		spanLength = span.end - span.start
		# mark cells that this cell covers to be deleted
		if spanLength > 1
			for offset in [1...spanLength]
				table[span.start+offset][frameId] = undefined

	###
	Sorts the targets and frame elements of the given annotated sentence into
	a table.
	Their row in the table is determined by the start of their span.
	Their column is based on their frame.
	###
	sortIntoTable: (sentence) ->
		numTokens = sentence.text.length
		numFrames = sentence.frames.length
		# initialize a 2d array with filler cells
		table = ((BLANK for x in [0...numFrames]) for y in [0...numTokens])
		[table.width, table.height] = [numFrames, numTokens]

		# drop each target and frame element into the appropriate spot in the
		# table, clearing room if necessary
		# NB: this could be problematic if some overlap
		for frame, frameId in sentence.frames
			for fe in frame.frame_elements
				table[fe.start][frameId] = new FrameElementCell(fe, frameId)
				@makeRoom(table, fe, frameId)
			target = frame.target
			table[target.start][frameId] = new TargetCell(target, frameId)
			@makeRoom(table, target, frameId)
		table

	###
	Takes the given semafor parse and renders it to html
	###
	render: (sentence) ->
		table = @sortIntoTable(sentence)

		#remove null cells
		for row, i in table
			table[i] = (x for x in row when x?)

		targetHeaders = (
			new TargetCell(frame.target, i) for frame, i in sentence.frames
		)
		tokenHeaders = (
			new Header(token, i) for token, i in sentence.text
		)

		rows = ({token: tokenHeaders[i], frames: row} for row, i in table)

		Mustache.to_html(
			FRAME_TABLE_TEMPLATE,
			{rows: rows, targetHeaders: targetHeaders}
		)

	###
	 Submits the content of the input textarea to the parse API endpoint,
	 and then renders and displays the response.
	###
	submitSentence: ->
		sentence = $(@inputArea).val()
		$.ajax(
			url: @parseUrl,
			data: {sentence: sentence},
			success: (data) => $(@displayDiv).html(@render(data.sentences[0]))
		)


# Make SemViz globally visible
if typeof module != "undefined" && module.exports
  #On a server
  globalObject = exports
else
  #On a client
  globalObject = window

globalObject.SemViz = SemViz
globalObject.semViz = new SemViz()
