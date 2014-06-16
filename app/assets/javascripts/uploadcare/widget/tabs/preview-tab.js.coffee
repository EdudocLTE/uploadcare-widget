{
  namespace,
  utils,
  ui: {progress},
  templates: {tpl},
  jQuery: $,
  crop: {CropWidget},
  locale: {t}
} = uploadcare

namespace 'uploadcare.widget.tabs', (ns) ->
  class ns.PreviewTab extends ns.BasePreviewTab

    constructor: ->
      super

      $.each @dialogApi.fileColl.get(), (i, file) =>
        @__setFile file

      @dialogApi.fileColl.onAdd.add @__setFile

    __setFile: (@file) =>
      ifCur = (fn) =>
        =>
          if file == @file
            fn.apply(null, arguments)

      @file.progress ifCur utils.once (info) =>
        @__setState 'unknown', {file: info.incompleteFileInfo}

      @file.done ifCur (file) =>
        state = if file.isImage then 'image' else 'regular'
        @__setState state, {file}

      @file.fail ifCur (error, file) =>
        @__setState 'error', {error, file}

    element: (name) ->
      @container.find('@uploadcare-dialog-preview-' + name)

    # error
    # unknown
    # image
    # regular
    __setState: (state, data) ->
      @container.empty().append tpl("tab-preview-#{state}", data)

      if state is 'unknown' and @settings.crop
        @element('done').hide()
      if state is 'image' and @settings.crop
        @__initCrop(data)

    __initCrop: (data) ->
      @element('title').text t('dialog.tabs.preview.crop.title')
      @element('done').text t('dialog.tabs.preview.crop.done')

      img = @element('image')
        .on 'error', =>
          @file = null
          @__setState 'error', error: 'loadImage'

      # crop widget can't get container size when container hidden
      # (dialog hidden) so we need timer here
      utils.defer =>
        return if not @file

        imgSize = [data.file.originalImageInfo.width, data.file.originalImageInfo.height]
        parentSize = [img.parent().width(), img.parent().height() or 640]
        widgetSize = utils.fitSize(imgSize, parentSize)
        img.css width: widgetSize[0], height: widgetSize[1], maxHeight: 'none'

        widget = new CropWidget img, imgSize, @settings.crop[0]
        widget.setSelectionFromModifiers(data.file.cdnUrlModifiers)

        @element('done').click =>
          opts = widget.getSelectionWithModifiers()
          @dialogApi.fileColl.replace @file, @file.then (info) =>
            info.cdnUrlModifiers = opts.modifiers
            info.cdnUrl = "#{info.originalUrl}#{opts.modifiers or ''}"
            info.crop = opts.crop
            info
