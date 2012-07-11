###
Hallo {{ VERSION }} - a rich text editing jQuery UI widget
(c) 2011 Henri Bergius, IKS Consortium
Hallo may be freely distributed under the MIT license
http://hallojs.org
###
((jQuery) ->
    # Hallo provides a jQuery UI widget `hallo`. Usage:
    #
    #     jQuery('p').hallo();
    #
    # Getting out of the editing state:
    #
    #     jQuery('p').hallo({editable: false});
    #
    # When content is in editable state, users can just click on
    # an editable element in order to start modifying it. This
    # relies on browser having support for the HTML5 contentEditable
    # functionality, which means that some mobile browsers are not
    # supported.
    #
    # If plugins providing toolbar buttons have been enabled for
    # Hallo, then a toolbar will be rendered when an area is active.
    #
    # ## Toolbar
    #
    # Hallo ships with different toolbar options, including:
    #
    # * `halloToolbarContextual`: a toolbar that appears as a popover 
    #   dialog when user makes a selection
    # * `halloToolbarFixed`: a toolbar that is constantly visible above
    #   the editable area when the area is activated
    #
    # The toolbar can be defined by the `toolbar` configuration key,
    # which has to conform to the toolbar widget being used.
    #
    # Just like with plugins, it is possible to use Hallo with your own
    # custom toolbar implementation.
    #
    # ## Events
    #
    # The Hallo editor provides several jQuery events that web
    # applications can use for integration:
    #
    # ### Activated
    #
    # When user activates an editable (usually by clicking or tabbing
    # to an editable element), a `halloactivated` event will be fired.
    #
    #     jQuery('p').bind('halloactivated', function() {
    #         console.log("Activated");
    #     });
    #
    # ### Deactivated
    #
    # When user gets out of an editable element, a `hallodeactivated`
    # event will be fired.
    #
    #     jQuery('p').bind('hallodeactivated', function() {
    #         console.log("Deactivated");
    #     });
    #
    # ### Modified
    #
    # When contents in an editable have been modified, a
    # `hallomodified` event will be fired.
    #
    #     jQuery('p').bind('hallomodified', function(event, data) {
    #         console.log("New contents are " + data.content);
    #     });
    #
    # ### Restored
    #
    # When contents are restored through calling 
    # `.hallo("restoreOriginalContent")` or the user pressing ESC while
    # the cursor is in the editable element, a 'hallorestored' event will
    # be fired.
    #
    #     jQuery('p').bind('hallorestored', function(event, data) {
    #         console.log("The thrown contents are " + data.thrown);
    #         console.log("The restored contents are " + data.content);
    #     });
    #
    jQuery.widget "IKS.hallo",
        toolbar: null
        bound: false
        originalContent: ""
        uuid: ""
        selection: null
        _keepActivated: false
        originalHref: null

        options:
            editable: true
            plugins: {}
            toolbar: 'halloToolbarContextual'
            parentElement: 'body'
            buttonCssClass: null
            placeholder: ''
            forceStructured: true

        _create: ->
            @id = @_generateUUID()

            for plugin, options of @options.plugins
                options = {} unless jQuery.isPlainObject options
                jQuery.extend options,
                  editable: this
                  uuid: @id
                  buttonCssClass: @options.buttonCssClass
                jQuery(@element)[plugin] options

            @element.one 'halloactivated', =>
                # We will populate the toolbar the first time this
                # editable is activated. This will make multiple
                # Hallo instances on same page load much faster
                @_prepareToolbar()

            @originalContent = @getContents()

        _init: ->
            if @options.editable
                @enable()
            else
                @disable()

        # Disable an editable
        disable: ->
            @element.attr "contentEditable", false
            @element.unbind "focus", @_activated
            @element.unbind "blur", @_deactivated
            @element.unbind "keyup paste change", @_checkModified
            @element.unbind "keyup", @_keys
            @element.unbind "keyup mouseup", @_checkSelection
            @bound = false

            @element.parents('a').andSelf().each (idx, elem) =>
              element = jQuery elem
              return unless element.is 'a'
              return unless @originalHref
              element.attr 'href', @originalHref

            @_trigger "disabled", null

        # Enable an editable
        enable: ->
            @element.parents('a[href]').andSelf().each (idx, elem) =>
              element = jQuery elem
              return unless element.is 'a[href]'
              @originalHref = element.attr 'href'
              element.removeAttr 'href'

            @element.attr "contentEditable", true

            unless @element.html()
                @element.html this.options.placeholder

            if not @bound
                @element.bind "focus", this, @_activated
                @element.bind "blur", this, @_deactivated
                @element.bind "keyup paste change", this, @_checkModified
                @element.bind "keyup", this, @_keys
                @element.bind "keyup mouseup", this, @_checkSelection
                widget = this
                @bound = true

            @_forceStructured() if @options.forceStructured

            @_trigger "enabled", null

        # Activate an editable for editing
        activate: ->
            @element.focus()

        # Only supports one range for now (i.e. no multiselection)
        getSelection: ->
            if jQuery.browser.msie
                range = document.selection.createRange()
            else
                if window.getSelection
                    userSelection = window.getSelection()
                else if (document.selection) #opera
                    userSelection = document.selection.createRange()
                else
                    throw "Your browser does not support selection handling"

                if userSelection.rangeCount > 0
                    range = userSelection.getRangeAt(0)
                else
                    range = userSelection

            return range

        restoreSelection: (range) ->
            if ( jQuery.browser.msie )
                range.select()
            else
                window.getSelection().removeAllRanges()
                window.getSelection().addRange(range)

        replaceSelection: (cb) ->
            if ( jQuery.browser.msie )
                t = document.selection.createRange().text;
                r = document.selection.createRange()
                r.pasteHTML(cb(t))
            else
                sel = window.getSelection();
                range = sel.getRangeAt(0);
                newTextNode = document.createTextNode(cb(range.extractContents()));
                range.insertNode(newTextNode);
                range.setStartAfter(newTextNode);
                sel.removeAllRanges();
                sel.addRange(range);

        removeAllSelections: () ->
            if ( jQuery.browser.msie )
                range.empty()
            else
                window.getSelection().removeAllRanges()

        # Get contents of an editable as HTML string
        getContents: ->
          # clone
          contentClone = @element.clone()
          for plugin of @options.plugins
            jQuery(@element)[plugin] 'cleanupContentClone', contentClone
          contentClone.html()

        # Set the contents of an editable
        setContents: (contents) ->
            @element.html contents

        # Check whether the editable has been modified
        isModified: ->
            @originalContent isnt @getContents()

        # Set the editable as unmodified
        setUnmodified: ->
            @originalContent = @getContents()

        # Set the editable as modified
        setModified: ->
            @._trigger 'modified', null,
                editable: @
                content: @getContents()

        # Restore the content original
        restoreOriginalContent: () ->
            @element.html(@originalContent)

        # Execute a contentEditable command
        execute: (command, value) ->
            if document.execCommand command, false, value
                @element.trigger "change"

        protectFocusFrom: (el) ->
            widget = @
            el.bind "mousedown", (event) ->
                event.preventDefault()
                widget._protectToolbarFocus = true
                setTimeout ->
                  widget._protectToolbarFocus = false
                , 300

        keepActivated: (@_keepActivated) ->

        _generateUUID: ->
            S4 = ->
                ((1 + Math.random()) * 0x10000|0).toString(16).substring 1
            "#{S4()}#{S4()}-#{S4()}-#{S4()}-#{S4()}-#{S4()}#{S4()}#{S4()}"

        _prepareToolbar: ->
            @toolbar = jQuery('<div class="hallotoolbar"></div>').hide()

            jQuery(@element)[@options.toolbar]
              editable: @
              parentElement: @options.parentElement
              toolbar: @toolbar

            for plugin of @options.plugins
                jQuery(@element)[plugin] 'populateToolbar', @toolbar

            jQuery(@element)[@options.toolbar] 'setPosition'
            @protectFocusFrom @toolbar

        _checkModified: (event) ->
            widget = event.data
            widget.setModified() if widget.isModified()

        _keys: (event) ->
            widget = event.data
            if event.keyCode == 27
                old = widget.getContents()
                widget.restoreOriginalContent(event)
                widget._trigger "restored", null,
                    editable: widget
                    content: widget.getContents()
                    thrown: old

                widget.turnOff()

        _rangesEqual: (r1, r2) ->
            r1.startContainer is r2.startContainer and r1.startOffset is r2.startOffset and r1.endContainer is r2.endContainer and r1.endOffset is r2.endOffset

        # Check if some text is selected, and if this selection has changed. If it changed,
        # trigger the "halloselected" event
        _checkSelection: (event) ->
            if event.keyCode == 27
                return

            widget = event.data

            # The mouseup event triggers before the text selection is updated.
            # I did not find a better solution than setTimeout in 0 ms
            setTimeout ()->
                sel = widget.getSelection()
                if widget._isEmptySelection(sel) or widget._isEmptyRange(sel)
                    if widget.selection
                        widget.selection = null
                        widget._trigger "unselected", null,
                            editable: widget
                            originalEvent: event
                    return

                if !widget.selection or not widget._rangesEqual sel, widget.selection
                    widget.selection = sel.cloneRange();
                    widget._trigger "selected", null,
                        editable: widget
                        selection: widget.selection
                        ranges: [widget.selection]
                        originalEvent: event
            , 0

        _isEmptySelection: (selection) ->
            if selection.type is "Caret"
                return true

            return false

        _isEmptyRange: (range) ->
            if range.collapsed
                return true
            if range.isCollapsed
                return range.isCollapsed() if typeof range.isCollapsed is 'function'
                return range.isCollapsed

            return false

        turnOn: () ->
            if this.getContents() is this.options.placeholder
                this.setContents ''

            jQuery(@element).addClass 'inEditMode'
            @_trigger "activated", @

        turnOff: () ->
            jQuery(@element).removeClass 'inEditMode'
            @_trigger "deactivated", @

            unless @getContents()
                @setContents @options.placeholder

        _activated: (event) ->
            event.data.turnOn()

        _deactivated: (event) ->
            return if event.data._keepActivated

            unless event.data._protectToolbarFocus is true
              event.data.turnOff()
            else
              setTimeout ->
                jQuery(event.data.element).focus()
              , 300

        _forceStructured: (event) ->
            try
                document.execCommand 'styleWithCSS', 0, false
            catch e
                try
                    document.execCommand 'useCSS', 0, true
                catch e
                    try
                        document.execCommand 'styleWithCSS', false, false
                    catch e

)(jQuery)