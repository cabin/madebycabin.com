from flask.ext.wtf import fields, widgets


class GroupedWidgets(object):
    """Renders grouped, titled lists of checkboxes.

    Only useful with a SelectMultipleGroupedField.
    """
    widget = widgets.Input(input_type='checkbox')

    def __call__(self, field, **kwargs):
        self.field = field
        return self.render_multiple(field.iter_choices())

    def render_multiple(self, iterable):
        html = []
        for value, label, selected in iterable:
            if hasattr(label, '__iter__'):
                html.append(
                    '<fieldset class="checkboxes">'
                    '<legend>%s</legend><ul>%s</ul></fieldset>' % (
                    value, self.render_multiple(label)))
            else:
                html.append(self.render_widget(value, label, selected))
        return ''.join(html)

    def render_widget(self, value, label, selected):
        kwargs = {'value': value}
        if selected:
            kwargs['checked'] = True
        return '<li><label>%s %s</label></li>' % (
            self.widget(self.field, **kwargs), label)


class SelectMultipleGroupedField(fields.SelectMultipleField):
    """A SelectMultipleField whose choices can be split into groups.

    `choices` can be `[(value, label), ...]` as in a normal SelectField, or
    instead can be nested with a label for each group:

        [(label, [(value, label), ...]), ...]

    Currently depends on `GroupedWidgets` for display. TODO: add customization.
    """
    widget = GroupedWidgets()

    def iter_choices(self, choices=None):
        choices = choices if choices is not None else self.choices
        for value, label in choices:
            if hasattr(label, '__iter__'):
                yield (value, self.iter_choices(label), None)
            else:
                selected = (self.data is not None and
                            self.coerce(value) in self.data)
                yield (value, label, selected)

    def pre_validate(self, form):
        if self.data:
            values = self._find_values(self.choices)
            for d in self.data:
                if d not in values:
                    raise ValueError(self.gettext(
                        "'%(value)s' is not a valid choice for this field")
                        % dict(value=d))

    def _find_values(self, choices):
        values = set()
        for value, label in choices:
            if hasattr(label, '__iter__'):
                values.update(self._find_values(label))
            else:
                values.add(value)
        return values


class StringListField(fields.Field):
    """A field whose input and output data are a list of strings.

    The list is rendered as a textarea split linewise for simple editing.
    """
    widget = widgets.TextArea()

    def process_data(self, value):
        if value:
            self.data = '\n'.join(value)
        else:
            self.data = ''

    def process_formdata(self, valuelist):
        self.data = valuelist[0].splitlines()

    def _value(self):
        return self.data if self.data else ''
